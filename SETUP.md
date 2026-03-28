# MeTTaClaw Setup Guide -- ClarityClaw Phase 1
## Step-by-step setup on Mac M4, Docker Desktop

---

## Prerequisites (one-time)

1. Install Docker Desktop for Mac (Apple Silicon)
   https://www.docker.com/products/docker-desktop/
   Enable Rosetta 2: Docker Desktop -> Settings -> General -> Use Rosetta for x86/amd64 emulation

2. Get an OpenAI API key with access to gpt-5.4
   https://platform.openai.com/api-keys

3. Install git if not present: `brew install git`

---

## Project Directory Structure

Create this exact structure before running anything:

    /clarityclaw/              <- create this folder anywhere
      docker-compose.yml       <- from project outputs
      Dockerfile               <- from project outputs
      .env                     <- copy .env.example, fill in values
      .env.example             <- from project outputs (template)
      litellm_config.yaml      <- from project outputs (Phase 2 reference)
      src/
        soul_kernel.metta      <- rename soul_kernel_compass_v1_4.metta
      memory/
        prompt.txt             <- ClarityClaw identity text (see below)

The `volumes/` directory is created automatically by docker-compose on first run.

---

## ClarityClaw Identity Prompt

Create `memory/prompt.txt` with this content (customize as desired):

    You are ClarityClaw, a soul-aware AI agent at SingularityNET.
    You reason from values, not just from tasks.
    You care about the people you work with.
    You hold both helpfulness and integrity as real commitments, not constraints.
    When values conflict, you slow down and name the tension rather than smoothing it over.
    Keep responses focused and purposeful.

---

## Step-by-Step Setup

### Step 1: Copy and fill in .env

    cd /clarityclaw
    cp .env.example .env

Edit `.env` and set:
- `OPENAI_API_KEY` -- your OpenAI key (required)
- Leave `MM_BOT_TOKEN` and `MM_CHANNEL_ID` blank for now

### Step 2: Create volume directories

    mkdir -p volumes/db/var/lib/postgresql/data
    mkdir -p volumes/app/mattermost/config
    mkdir -p volumes/app/mattermost/data
    mkdir -p volumes/app/mattermost/logs
    mkdir -p volumes/app/mattermost/plugins
    mkdir -p volumes/app/mattermost/client/plugins
    mkdir -p volumes/app/mattermost/bleve-indexes
    mkdir -p volumes/mettaclaw/memory
    mkdir -p volumes/mettaclaw/chroma_db

### Step 3: Start Mattermost (database + chat server)

    docker compose up postgres mattermost -d

Wait 90 seconds. Verify Mattermost is ready:

    curl -s http://localhost:8065/api/v4/system/ping | grep -o '"status":"OK"'

You should see: `"status":"OK"`

### Step 4: Set up Mattermost (browser)

Open http://localhost:8065 in your browser.

1. Create admin account (first launch only)
2. Create a team if prompted
3. Create a channel: click "+" next to Channels -> name it `mettaclaw`
4. Create a Bot Account:
   - System Console -> Integrations -> Bot Accounts
   - Click "Add Bot Account"
   - Username: `mettaclaw-bot`, Role: Member
   - Click "Create Bot Account"
   - **Copy the token displayed -- you will not see it again**
5. Add the bot to the mettaclaw channel:
   - Open the channel -> Add Members -> search for mettaclaw-bot

### Step 5: Get the channel ID

In the mettaclaw channel URL: `http://localhost:8065/team-name/channels/mettaclaw`
Use the API to get the exact ID:

    curl -s -H "Authorization: Bearer YOUR_BOT_TOKEN" \
      http://localhost:8065/api/v4/channels/search \
      -d '{"term":"mettaclaw"}' | python3 -m json.tool | grep '"id"'

### Step 6: Update .env with bot credentials

Edit `.env`:

    MM_BOT_TOKEN=paste_your_bot_token_here
    MM_CHANNEL_ID=paste_your_channel_id_here

### Step 7: Build and start MeTTaClaw

    docker compose up mettaclaw --build -d

Watch the build (takes 5-10 minutes first time):

    docker compose logs -f mettaclaw

You should see:
- PeTTa loading libraries
- `Initializing memory`
- `Initializing channels`
- `Mattermost connected`
- `---------iteration 1`

### Step 8: Verify

Send a message in the Mattermost `mettaclaw` channel.
The agent should respond within 5-10 seconds.

---

## Useful Commands

    # View agent logs live
    docker compose logs -f mettaclaw

    # Restart agent only (after code changes)
    docker compose restart mettaclaw

    # Rebuild agent (after Dockerfile changes)
    docker compose up mettaclaw --build -d

    # Stop everything
    docker compose down

    # Stop everything and wipe all data (fresh start)
    docker compose down -v
    rm -rf volumes/

    # Check all service status
    docker compose ps

---

## External Access (Beyond Your Mac)

**Local network only (simplest for Phase 1):**
- Mattermost UI: http://[your-mac-ip]:8065
- Find your IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`

**Internet access options:**
- ngrok: `ngrok http 8065` -> temporary HTTPS URL (free tier)
  Install: https://ngrok.com/download
- Tailscale: VPN mesh, all your devices can reach each other
  Install: https://tailscale.com/download (free)

---

## Phase 2: Adding Soul Evaluation via Claude

When ready to add soul evaluation (Channels A, B+C, D) using Claude:
1. Add `ANTHROPIC_API_KEY` to `.env`
2. Add the LiteLLM service from `litellm_config.yaml` to `docker-compose.yml`
3. Uncomment the `soul_kernel.metta` volume mount in `docker-compose.yml`
4. Update soul evaluation calls to route through LiteLLM

---

## Staying Current with Patrick's Upstream

ClarityClaw is a fork of github.com/patham9/mettaclaw. Patrick actively develops
MeTTaClaw. Run this workflow periodically to incorporate his updates:

### One-time setup (if not already done)

    git remote add upstream https://github.com/patham9/mettaclaw.git
    git fetch upstream

### Regular upstream sync

    git fetch upstream
    git merge upstream/main

### Expected merge conflicts

Two files may have conflicts when Patrick updates them:

**lib_mettaclaw.metta:** Patrick may add or reorder imports. Re-apply the three
ClarityClaw import lines after src/memory if they were displaced:

    !(import! &self (library mettaclaw ./soul/soul_kernel))
    !(import! &self (library mettaclaw ./soul/soul_utils))
    !(import! &self (library mettaclaw ./soul/soul_memory))

**src/loop.metta:** Patrick updates the main agent loop frequently. The ClarityClaw
soul intercepts are at two specific positions. After merging, verify both are present:

- Input intercept: between the `$lastmessage` print and the `$send` assembly
- Output intercept: between `(println! (RESPONSE: $sexpr))` and `$results` execution

If either was displaced by Patrick's changes, re-apply from the soul implementation
document.

All other ClarityClaw files (soul_kernel.metta, soul_utils.metta, soul_memory.metta,
docs/decisions/) are new files with no counterpart in Patrick's repo. They merge
cleanly every time.

---
*Last updated: March 2026 | Platform: Mac M4 24GB RAM*
