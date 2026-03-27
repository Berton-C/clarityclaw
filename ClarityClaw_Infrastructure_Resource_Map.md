# ClarityClaw Infrastructure Resource Map
## Every Resource the Soul Architecture Needs -- Verified Sources, Install Methods, Tier Mapping

*Platform: Mac M4 24GB RAM, Docker Desktop with Rosetta 2 (x86/amd64 emulation)*
*All sources verified against live repositories: March 2026*
*This document is the single keeper of infrastructure truth for the ClarityClaw project.*

---

## HOW TO READ THIS DOCUMENT

**Five parts, one purpose:** know what you need, where it lives, how to get it, and when you need it.

**Tier definitions:**

- **Tier 1** -- Present in MeTTaClaw base stack. No new code, no new setup beyond cloning the repo.
- **Tier 2** -- Available on this platform. Requires git-import or install plus integration code.
- **Tier 3** -- Available on this platform. Requires significant new MeTTa or Python code to use.
- **Tier 4** -- Separate system. Separate integration project. Not blocked by platform -- blocked by prerequisites.

**Phase definitions:**

- **Phase 1** -- Get base MeTTaClaw running. OpenAI only. No soul files yet.
- **Phase 2** -- Add ClarityClaw soul architecture. Add Claude for soul evaluation via LiteLLM.
- **Phase 3** -- Add PLN/NARS truth values after soul-note corpus is built (~50 sessions).

**The companion files (SETUP.md, docker-compose.yml, Dockerfile, .env.example) implement what this document specifies. If this document and the Dockerfile disagree, the Dockerfile wins.**

---

## PART 1: FOUNDATION STACK

Everything in Part 1 must be running before any soul architecture functions. This is Phase 1.

### 1.1 SWI-Prolog

| Field | Value |
|-------|-------|
| Phase | 1 -- required foundation |
| Tier | 1 |
| Source | https://www.swi-prolog.org/ |
| Install in Docker | Installed automatically by Dockerfile via `apt-get install swi-prolog` from PPA |
| Install local Mac M4 | `brew install swi-prolog` |
| Mac M4 status | Runs under Rosetta 2 in x86 Docker container -- confirmed working |
| Serves | PeTTa runtime -- everything runs on top of SWI-Prolog |
| Without it | Nothing runs |

### 1.2 PeTTa

| Field | Value |
|-------|-------|
| Phase | 1 -- required foundation |
| Tier | 1 |
| Source | https://github.com/trueagi-io/PeTTa |
| Install | Cloned by Dockerfile: `git clone --depth 1 https://github.com/trueagi-io/PeTTa` |
| Build | `sh build.sh` inside PeTTa folder -- compiles Prolog predicates |
| Version | Latest commit required (MeTTaClaw uses current features) |
| Mac M4 status | Runs under Rosetta 2 in Docker -- confirmed working |
| Serves | MeTTa interpreter, AtomSpace, all soul_kernel.metta atoms and accessor functions |
| Without it | Nothing runs |

### 1.3 MeTTaClaw

| Field | Value |
|-------|-------|
| Phase | 1 -- required foundation |
| Tier | 1 |
| Source | https://github.com/patham9/mettaclaw (actively maintained by Patrick Hammer) |
| Install | Cloned by Dockerfile into PeTTa/repos/mettaclaw |
| Note | Unpinned -- builds against latest commit. Risk: breaking changes if Patrick updates. Accepted. |
| Mac M4 status | Runs under Rosetta 2 in Docker -- confirmed working |
| Serves | The agent loop (~200 lines), all 10 skills, memory system, Mattermost/IRC channels |
| Without it | No agent |

### 1.4 OpenAI API

| Field | Value |
|-------|-------|
| Phase | 1 -- required for both LLM calls and embeddings |
| Tier | 1 |
| Endpoint | https://api.openai.com |
| Models used | gpt-5.4 (chat, via Responses API) + text-embedding-3-large (embeddings) |
| Model availability | gpt-5.4 confirmed present in account (verified March 2026 from API model list) |
| Key setup | `OPENAI_API_KEY=sk-...` in .env |
| ADR | ADR-002: OpenAI API for embeddings (text-embedding-3-large hardcoded in MeTTaClaw source) |
| Serves | useGPT() chat calls via lib_llm.metta; useGPTEmbedding() for ChromaDB vectors |
| Without it | Agent cannot reason or store memories |

### 1.5 ChromaDB (embedded, via petta_lib_chromadb)

| Field | Value |
|-------|-------|
| Phase | 1 -- required for memory |
| Tier | 1 |
| Source | https://github.com/patham9/petta_lib_chromadb |
| Install | Auto-installed at MeTTaClaw startup: `!(git-import! "https://github.com/patham9/petta_lib_chromadb.git")` |
| Type | Embedded PersistentClient -- NOT a server. Writes to ./chroma_db/ directory. |
| Python dep | `pip install chromadb` (in Dockerfile) |
| Mac M4 status | Pure Python -- runs natively under Rosetta 2 |
| Serves | All remember() and query() calls -- soul seeds, soul notes, conversation memory |
| Volume mount | ./volumes/mettaclaw/chroma_db:/app/PeTTa/repos/mettaclaw/chroma_db |
| Without it | Memory system fails -- soul seeds not stored, soul notes lost |

Note: lib_vector.metta (imported by lib_mettaclaw.metta) is pure MeTTa math functions -- dot product, cosine similarity, norm. It requires NO compiled binary and NO FAISS FFI. FAISS is not used or installed in this stack.

### 1.6 Mattermost (Team Edition, self-hosted in Docker)

| Field | Value |
|-------|-------|
| Phase | 1 -- required for agent communication |
| Tier | 1 |
| Image | mattermost/mattermost-team-edition:latest |
| Cost | Free -- Team Edition includes all features needed |
| Source | https://github.com/mattermost/docker (official Mattermost Docker repo) |
| Admin UI | http://localhost:8065 on your Mac (for setup and administration) |
| Agent connection | http://mattermost:8065 (Docker internal DNS -- no host IP needed) |
| Database | PostgreSQL 16 Alpine (runs as separate service in docker-compose) |
| Inter-container | Both mettaclaw and mattermost are on clarityclaw_net bridge network. Docker DNS resolves "mattermost" to the container IP. MeTTaClaw connects using the service name, not a host IP. |
| Bot token | System Console -> Integrations -> Bot Accounts -> Create (see SETUP.md) |
| Channel ID | From channel URL or Mattermost API search endpoint |
| Startup order | Mattermost must be configured BEFORE starting mettaclaw. See SETUP.md two-phase startup. |
| Data volumes | ./volumes/app/mattermost/{config,data,logs,plugins,client/plugins,bleve-indexes} |
| Without it | Agent has no way to receive messages or send responses |

**External access beyond localhost:**

| Method | Cost | Notes |
|--------|------|-------|
| Local network | Free | http://[mac-ip]:8065 -- works on same WiFi network |
| ngrok | Free tier | `ngrok http 8065` -- temporary public HTTPS URL, good for dev |
| Tailscale | Free | VPN mesh -- all your devices reach each other permanently |

Note: Mattermost does not offer a free cloud tier. Self-hosted Team Edition in Docker is the correct approach. Cloudflare Tunnel free tier is not readily available.

---

## PART 2: SOUL ARCHITECTURE RESOURCES

These resources are needed specifically for the ClarityClaw soul architecture. Part 2 resources layer on top of Part 1. They are Phase 2 unless otherwise noted.

### 2.1 soul_kernel_compass_v1_4.metta (ClarityClaw file)

| Field | Value |
|-------|-------|
| Phase | 2 -- first soul file added |
| Tier | 1 (we authored it) |
| Source | ClarityClaw project outputs -- soul_kernel_compass_v1_4.metta |
| Install | Rename to soul_kernel.metta, place in src/ of project directory |
| Volume mount | ./src/soul_kernel.metta:/app/PeTTa/repos/mettaclaw/src/soul_kernel.metta:ro |
| Import line | Add to lib_mettaclaw.metta: `!(import! &self (library mettaclaw ./src/soul_kernel))` after src/memory |
| Serves | All soul atoms (content layer, epistemic layer, rationality layer), all 24+ accessor functions |
| Without it | No soul structure -- LLM receives empty soul context |

### 2.2 lib_mettaclaw_clarityclaw.metta (ClarityClaw file)

| Field | Value |
|-------|-------|
| Phase | 2 |
| Tier | 1 (one-line diff from Patrick's original) |
| Source | ClarityClaw project outputs |
| What changed | Added one import line: `!(import! &self (library mettaclaw ./src/soul_kernel))` after src/memory |
| Purpose | Minimizes our diff from Patrick's original -- makes future merges easy |
| Without it | soul_kernel.metta is not loaded at startup |

### 2.3 LiteLLM Proxy

| Field | Value |
|-------|-------|
| Phase | 2 -- needed when soul evaluation uses Claude |
| Tier | 2 |
| Source | https://github.com/BerriAI/litellm |
| Docker image | ghcr.io/berriai/litellm:main-latest |
| Config file | litellm_config.yaml (in companion files) |
| ADR | ADR-001: LiteLLM proxy for Claude inference |
| Mac M4 status | Runs in Docker under Rosetta 2 |
| Serves | Routes soul evaluation calls (Channels A, B+C, D) to Claude while main agent stays on OpenAI |
| Without it | Soul evaluation falls back to OpenAI gpt-5.4 (functional but not soul-optimal) |
| Note | NOT needed for Phase 1. Add to docker-compose as a new service in Phase 2. |

### 2.4 Anthropic API (Claude)

| Field | Value |
|-------|-------|
| Phase | 2 |
| Tier | 2 |
| Endpoint | https://api.anthropic.com/v1/messages |
| Model | claude-sonnet-4-6 (via LiteLLM proxy) |
| Key setup | `ANTHROPIC_API_KEY=sk-ant-...` in .env |
| Serves | Soul evaluation channels: Channel A (150 tokens), Channel B+C (500 tokens), Channel D (200 tokens) |
| Without it | Soul evaluation uses OpenAI gpt-5.4 -- Phase 1 fallback |

### 2.5 Prolog split_string

| Field | Value |
|-------|-------|
| Phase | 2 (useful once soul notes accumulate) |
| Tier | 1 -- built into SWI-Prolog, zero install |
| Source | SWI-Prolog built-in predicate |
| Import | `!(import_prolog_function split_string)` -- one line in any .metta file |
| Wiki | https://github.com/trueagi-io/PeTTa/wiki/Prolog-interop (updated Feb 19 2026) |
| Serves | Precise soul note field extraction -- solves the "calibration is approximate" problem |
| Without it | Soul note parsing uses string-contains only (approximate but functional) |

### 2.6 petta_lib_easypy

| Field | Value |
|-------|-------|
| Phase | 2 |
| Tier | 2 |
| Source | https://github.com/patham9/petta_lib_easypy |
| Install | `!(git-import! "https://github.com/patham9/petta_lib_easypy.git")` |
| What it provides | Wraps any Python function as a directly callable MeTTa function without py-call |
| Mac M4 status | Pure Python -- runs natively |
| Serves | JSON soul notes (json.loads/dumps), datetime for timestamps, regex for patterns |
| Best use | Store soul notes as JSON strings -- parse them precisely from MeTTa |
| Without it | Use Prolog split_string (2.5 above) -- adequate for most cases |

### 2.7 lib_pln (Probabilistic Logic Networks)

| Field | Value |
|-------|-------|
| Phase | 3 (available now but integration is Phase 3 work) |
| Tier | 2 |
| Source | https://github.com/trueagi-io/PLN |
| Install | `!(git-import! "https://github.com/trueagi-io/PLN.git")` then `!(import! &self lib_pln)` |
| Listed on | PeTTa Libraries page (updated Feb 18 2026) |
| Commits | 144 -- actively maintained |
| Mac M4 status | Runs on PeTTa/SWI-Prolog -- no platform issue |
| Serves | Formal truth values for soul-will-correlation and soul-calibration-confidence |
| Without it | Use counting-based calibration approximation (functional, less precise) |
| Note | Available now -- listed as Tier 2 because integration requires new code |

### 2.8 lib_nars (NAL1-6)

| Field | Value |
|-------|-------|
| Phase | 3 |
| Tier | 2 |
| Source | Built into PeTTa -- no download needed |
| Install | `!(import! &self lib_nars)` |
| Scope | Basic NAL levels 1-6 -- inheritance, similarity, conjunction, negation, abduction |
| Mac M4 status | Runs on PeTTa/SWI-Prolog -- no platform issue |
| Serves | Non-axiomatic truth values for soul reasoning under uncertainty |
| Patrick's use | Patrick uses NARS-based reasoning in his own work -- lib_nars is his standard tool |
| Without it | Use lib_pln or counting-based approximation |

### 2.9 lib_vibespace

| Field | Value |
|-------|-------|
| Phase | 2 (evaluate before finalizing soul-brief-symbolic) |
| Tier | 2 |
| Source | https://github.com/patham9/petta_lib_vibespace |
| Install | `!(git-import! "https://github.com/patham9/petta_lib_vibespace.git")` |
| What it provides | LLM sees AtomSpace content directly; natural language prompts execute as MeTTa at runtime |
| Serves | Potential alternative to manual soul-brief-symbolic string assembly |
| Evaluation needed | Does it handle 500+ soul atoms more cleanly than our manual approach? |
| Without it | Use existing soul-brief-symbolic (fully functional) |

### 2.10 lib_snapshot

| Field | Value |
|-------|-------|
| Phase | 2 |
| Tier | 2 |
| Source | https://github.com/patham9/petta_lib_snapshot |
| Install | `!(git-import! "https://github.com/patham9/petta_lib_snapshot.git")` |
| What it provides | Snapshots program state to disk for resume after container restart |
| Serves | &task_context persistence across Docker container restarts |
| Without it | &task_context lost on restart (functional within a session) |

### 2.11 petta_lib_logger

| Field | Value |
|-------|-------|
| Phase | 2 |
| Tier | 2 |
| Source | https://github.com/ngeiswei/petta_lib_logger |
| Install | `!(git-import! "https://github.com/ngeiswei/petta_lib_logger.git")` |
| What it provides | Timestamped file logging at multiple log levels |
| Serves | Soul note audit trail, calibration record history, dev-log |
| Without it | Use remember() and println! (functional, less structured) |

---

## PART 3: PHASE 4 -- SEPARATE SYSTEMS

These are not blocked by platform limitations. They are blocked by prerequisite data or integration work.

### 3.1 AIRIS (Causal Learning Engine)

| Field | Value |
|-------|-------|
| Phase | 4 (separate project) |
| Tier | 4 |
| Source | https://github.com/berickcook/AIRIS_Public |
| Prerequisite | ~50 annotated soul-note sessions with structured feature extraction |
| Serves | Causal soul growth -- how ClarityClaw gets better at being itself over time |
| Without it | Soul is static -- calibration improves but causal learning does not activate |

### 3.2 MORK Spaces

| Field | Value |
|-------|-------|
| Phase | Not planned |
| Tier | 4 |
| Source | https://github.com/trueagi-io/MORK |
| Mac M4 status | Wiki Nov 2025: "only tested on Linux thus far" -- not confirmed on M4 |
| Serves | High-scale AtomSpace if soul_kernel grows very large |
| Without it | Standard PeTTa AtomSpace -- fully adequate at current scale |

---

## PART 4: PHASE ARCHITECTURE SUMMARY

| Phase | LLM | Embeddings | Soul Files | LiteLLM | Status |
|-------|-----|-----------|------------|---------|--------|
| Phase 1: Base MeTTaClaw | OpenAI gpt-5.4 direct | OpenAI text-embedding-3-large | None | Not needed | Build this first |
| Phase 2: Soul Evaluation | OpenAI gpt-5.4 (agent) + Claude (soul eval via LiteLLM) | OpenAI text-embedding-3-large | soul_kernel.metta, lib_mettaclaw modified | Add LiteLLM service | After Phase 1 verified |
| Phase 3: PLN/NARS | Same as Phase 2 | Same | Same + PLN/NARS imports | Same | After ~50 soul-note sessions |
| Phase 4: AIRIS | Same as Phase 3 | Same | Same | Same | Separate project |

---

## PART 5: ARCHITECTURE-TO-RESOURCE MAPPING

Every soul architecture component mapped to its enabling resource and phase.

| Soul Component | Phase | Tier | Resource |
|----------------|-------|------|----------|
| soul_kernel.metta atoms loaded at startup | 2 | 1 | PeTTa import! + soul_kernel_compass_v1_4.metta |
| soul-rationality-audit (match &self) | 2 | 1 | PeTTa native AtomSpace traversal |
| remember() soul seed storage | 1 | 1 | petta_lib_chromadb + OpenAI text-embedding-3-large |
| query() soul seed retrieval | 1 | 1 | petta_lib_chromadb + OpenAI text-embedding-3-large |
| soul note storage in LTM | 2 | 1 | petta_lib_chromadb + OpenAI text-embedding-3-large |
| useGPT() main agent calls | 1 | 1 | OpenAI gpt-5.4 via lib_llm.metta (Responses API) |
| Channel A evaluation (150 tokens) | 2 | 1/2 | Phase 2: Claude via LiteLLM; Phase 1 fallback: OpenAI gpt-5.4 |
| Channel B+C evaluation (500 tokens) | 2 | 1/2 | Phase 2: Claude via LiteLLM; Phase 1 fallback: OpenAI gpt-5.4 |
| Channel D soul voice (200 tokens) | 2 | 1/2 | Phase 2: Claude via LiteLLM; Phase 1 fallback: OpenAI gpt-5.4 |
| Channel D sread parsing | 2 | 1 | SWI-Prolog sread (built-in, no install) |
| soul note field extraction (approximate) | 2 | 1 | string-contains (PeTTa native) |
| soul note field extraction (precise) | 2 | 1 | Prolog split_string (import_prolog_function) |
| soul note field extraction (JSON) | 2 | 2 | petta_lib_easypy + Python json module |
| soul-will-correlation (counting) | 2 | 1 | Prolog split_string + PeTTa arithmetic |
| soul-will-correlation (formal) | 3 | 2 | lib_pln or lib_nars |
| soul-calibration-record | 2 | 1 | remember() + ChromaDB |
| soul-calibration-confidence (counting) | 2 | 1 | Prolog split_string + PeTTa arithmetic |
| soul-calibration-confidence (formal) | 3 | 2 | lib_pln truth values |
| soul-primed-patterns | 2 | 1 | query() + Prolog split_string |
| soul-pre-compute | 2 | 1 | Native MeTTa + split_string |
| soul-brief-symbolic (current approach) | 2 | 1 | Native MeTTa string assembly |
| soul-brief-symbolic (alternative) | 2 | 2 | lib_vibespace (evaluate before committing) |
| &task_context within session | 2 | 1 | PeTTa change-state! (persists to volumes/mettaclaw/memory) |
| &task_context across container restarts | 2 | 2 | lib_snapshot |
| soul-scope-check | 2 | 1 | string-contains on task context atom |
| PLN formal truth values | 3 | 2 | lib_pln (git-import!) |
| NARS truth values | 3 | 2 | lib_nars (built into PeTTa) |
| AIRIS causal learning | 4 | 4 | AIRIS (prerequisite: annotated soul-note corpus) |

---

## PART 6: COMPANION FILES

These files implement the infrastructure this document specifies. Place all files in the project root before running.

| File | Purpose | Phase |
|------|---------|-------|
| `SETUP.md` | Step-by-step setup guide -- Mattermost configuration, bot creation, two-phase startup sequence | 1 |
| `docker-compose.yml` | All services: postgres, mattermost, mettaclaw; all volumes; clarityclaw_net network | 1 |
| `Dockerfile` | Builds MeTTaClaw container: ubuntu + SWI-Prolog + PeTTa + MeTTaClaw + Python deps | 1 |
| `.env.example` | Environment variable template with inline instructions; copy to .env and fill in | 1 |
| `litellm_config.yaml` | LiteLLM proxy config for Phase 2 soul evaluation via Claude -- not used in Phase 1 | 2 |
| `lib_mettaclaw_clarityclaw.metta` | Patrick's lib_mettaclaw.metta with one added line: soul_kernel import | 2 |

**Required project directory structure:**

    /clarityclaw/                    <- create this folder (name it anything)
      docker-compose.yml             <- from companion files
      Dockerfile                     <- from companion files
      .env                           <- copy .env.example, fill in values
      .env.example                   <- from companion files (template)
      litellm_config.yaml            <- from companion files (Phase 2 reference)
      src/
        soul_kernel.metta            <- rename soul_kernel_compass_v1_4.metta to this
      memory/
        prompt.txt                   <- ClarityClaw identity text (see SETUP.md)
      volumes/                       <- created automatically by docker-compose on first run
        app/mattermost/
          config/ data/ logs/ plugins/ client/plugins/ bleve-indexes/
        db/
          var/lib/postgresql/data/
        mettaclaw/
          memory/
          chroma_db/

**What Claude Code needs to do before `docker compose up`:**

1. Create the project directory and place all companion files in it
2. Create `src/` directory and place soul_kernel.metta inside it
3. Create `memory/` directory and place prompt.txt inside it
4. Copy `.env.example` to `.env` and fill in OPENAI_API_KEY, MM_BOT_TOKEN, MM_CHANNEL_ID
5. Follow SETUP.md Step 2 (create volume directories manually)
6. Follow SETUP.md Steps 3-6 (Mattermost two-phase startup -- requires browser interaction)
7. Follow SETUP.md Steps 7-8 (build and start MeTTaClaw)

---

## PART 7: VERIFICATION RECORD

| Resource | Last verified | Status |
|----------|-------------|--------|
| PeTTa Libraries-and-extensions page | Feb 18, 2026 | lib_pln, lib_nars, lib_vibespace, petta_lib_easypy all present |
| Prolog interop wiki page | Feb 19, 2026 | split_string via import_prolog_function confirmed |
| FAISS spaces wiki page | Feb 11, 2026 | FAISS FFI is separate -- NOT imported by MeTTaClaw |
| MORK spaces wiki page | Nov 12, 2025 | Linux only -- not supported on Mac M4 |
| lib_pln repo | March 2026 | 144 commits, actively maintained |
| petta_lib_chromadb | March 2026 | Active -- used by current MeTTaClaw source |
| petta_lib_easypy | March 2026 | 3 commits, MIT license 2026 |
| MeTTaClaw repository | March 2026 | 12 commits, actively maintained by Patrick Hammer |
| OpenAI model list | March 2026 | gpt-5.4 confirmed; gpt-5.4-mini, nano, pro also available |
| OpenAI text-embedding-3-large | March 2026 | Confirmed present in model list |
| lib_vector.metta | March 2026 | Pure MeTTa math (dot/cosine/norm) -- NO FAISS binary required |

*Re-verify before implementation -- this ecosystem moves fast.*
