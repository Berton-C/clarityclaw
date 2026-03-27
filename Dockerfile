# Dockerfile -- ClarityClaw / MeTTaClaw
# Platform: linux/amd64 (runs under Rosetta 2 on Mac M4)
#
# KEY DESIGN DECISION:
#   Clones from github.com/Berton-C/clarityclaw -- NOT Patrick's repo.
#   run.metta uses local import only -- no git-import! at runtime.
#   This means Patrick's updates never overwrite your changes.
#   To update: merge patham9/mettaclaw into Berton-C/clarityclaw,
#   push, then: docker compose build mettaclaw

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    git \
    build-essential \
    gnupg \
    python3 \
    python3-pip \
    python3-dev \
    && gpg --keyserver keyserver.ubuntu.com --recv-keys E8B739E3753FF4A12360BA6A4AB3A5F60EA9AEB3 \
    && gpg --export E8B739E3753FF4A12360BA6A4AB3A5F60EA9AEB3 > /usr/share/keyrings/swi-prolog-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/swi-prolog-archive-keyring.gpg] https://ppa.launchpadcontent.net/swi-prolog/stable/ubuntu jammy main" > /etc/apt/sources.list.d/swi-prolog.list \
    && apt-get update \
    && apt-get install -y swi-prolog \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
    openai \
    chromadb \
    requests \
    websocket-client \
    sexpdata

WORKDIR /app

RUN git clone --depth 1 https://github.com/trueagi-io/PeTTa /app/PeTTa

RUN cd /app/PeTTa && sh build.sh

RUN git clone --depth 1 https://github.com/Berton-C/clarityclaw /app/PeTTa/repos/mettaclaw

RUN echo ":- asserta(library_path('/app/PeTTa/repos/mettaclaw'))." >> /app/PeTTa/src/main.pl
RUN git clone --depth 1 https://github.com/patham9/petta_lib_chromadb /app/PeTTa/repos/petta_lib_chromadb

RUN mkdir -p /app/PeTTa/repos/mettaclaw/memory \
             /app/PeTTa/repos/mettaclaw/chroma_db

ENV PYTHONPATH="/app/PeTTa/repos/petta_lib_chromadb"
ENV HOME=/root
ENV PYTHONUNBUFFERED=1

WORKDIR /app/PeTTa
CMD ["sh", "run.sh", "repos/mettaclaw/run.metta", "default"]
