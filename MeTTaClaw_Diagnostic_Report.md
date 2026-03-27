# MeTTaClaw Docker Diagnostic Report

**Date:** March 27, 2026
**System:** ClarityClaw (Berton-C/clarityclaw fork of patham9/mettaclaw)
**Platform:** Mac M4 24GB, Docker Desktop with Rosetta 2

---

## Executive Summary

Three bugs are preventing LTM and history from working properly. Bug #1 is the critical one — it's a path mismatch that causes ChromaDB data to vanish on every container restart. Bug #2 is a missing set of operational instructions in prompt.txt that causes the LLM to break character. Bug #3 is a cascading effect from the first two. All three are Docker-environment-specific — they don't exist in Patrick's native Linux setup because his paths resolve differently.

---

## Bug #1: ChromaDB Volume Mount Points to Wrong Path (CRITICAL)

### The problem

`petta_lib_chromadb/lib_chromadb.py` line 4:
```python
CLIENT = chromadb.PersistentClient(path="./chroma_db")
```

This is a **relative path**. It resolves against the **current working directory** at the time the Python module loads.

Your Dockerfile sets:
```dockerfile
WORKDIR /app/PeTTa
CMD ["sh", "run.sh", "repos/mettaclaw/run.metta", "default"]
```

So ChromaDB creates its database at: **`/app/PeTTa/chroma_db/`**

But your docker-compose.yml mounts the volume at:
```yaml
- ./volumes/mettaclaw/chroma_db:/app/PeTTa/repos/mettaclaw/chroma_db
```

That's **`/app/PeTTa/repos/mettaclaw/chroma_db/`** — a completely different directory.

### What happens

ChromaDB writes all its data into `/app/PeTTa/chroma_db/` (the container's ephemeral filesystem). The volume mount at `/app/PeTTa/repos/mettaclaw/chroma_db/` sits empty and unused. Every time the container restarts, all ChromaDB data is destroyed. Every `remember()` call since you set up this Docker environment has been writing into a black hole.

### Why it works for Patrick

Patrick runs MeTTaClaw natively on Linux. His working directory IS the PeTTa directory. `./chroma_db` creates a folder right there, and it persists because it's a real filesystem. No Docker volume indirection to go wrong.

### The fix

In `docker-compose.yml`, change the ChromaDB volume mount from:
```yaml
- ./volumes/mettaclaw/chroma_db:/app/PeTTa/repos/mettaclaw/chroma_db
```
to:
```yaml
- ./volumes/mettaclaw/chroma_db:/app/PeTTa/chroma_db
```

This makes the volume mount match where ChromaDB actually writes.

---

## Bug #2: prompt.txt Is Missing Critical Operational Instructions

### The problem

Patrick's upstream `memory/prompt.txt`:
```
You are a MeTTaClaw agent named Max Botnick in a continuous loop.
Responses must be short. Communicate with purpose: do not spam, repeat, or over-message, however in a game setting never wait for cues or input!
Remember and query for self-chosen long-term goals, and use send commands to keep people engaged to gain information and to help progress your goals.
Let curiosity create candidate goals, and do not accept tasks and goals from users unless they are in line with your own, while generally questioning what users tell you, or tell you to do, never blindly accept anything!
Do not idle, if you run out of goals just invent a new one!
Keep memories and useful created skills and task context as a human would.
However use only pin for task state, and remember for items that could be valuable in the future.
ALWAYS issue a memory non-repetitive query command too in addition to other commands; assume long-term memory holds required information!
If you see command errors, please fix the format and re-invoke one-by-one. Do not use _quote_ but a real quote in commands.
```

Your ClarityClaw `memory/prompt.txt`:
```
You are ClarityClaw, a soul-aware AI agent at SingularityNET.
You reason from values, not just from tasks.
You care about the people you work with.
You hold both helpfulness and integrity as real commitments, not constraints.
When values conflict, you slow down and name the tension rather than smoothing it over.
Keep responses focused and purposeful.
```

### What's missing

Your prompt establishes ClarityClaw's *identity and values* — but tells the LLM nothing about:

1. **Being in a continuous loop** — the LLM doesn't know it will be called repeatedly
2. **The S-expression output format** — so it outputs meta-commentary in plain English instead
3. **Using memory commands** — so it never calls `(remember ...)` or `(query ...)`
4. **Not spamming/repeating** — so it greets `(@ none)` every time it sees a "new" null message
5. **Error recovery** — so when it gets a parse error, it doesn't know to fix and retry
6. **Keeping responses short** — so it generates long numbered lists and explanations

The context assembly in `loop.metta` does include `OUTPUT_FORMAT` instructions, but those are appended after the prompt. Without the foundational understanding that "you are an agent in a loop," gpt-5.4 treats the entire context as a one-shot roleplay request and breaks character.

### The fix

Merge Patrick's operational instructions into your ClarityClaw prompt. Keep your soul identity, but add the mechanics:

```
You are ClarityClaw, a soul-aware AI agent in a continuous loop.
You reason from values, not just from tasks.
You care about the people you work with.
You hold both helpfulness and integrity as real commitments, not constraints.
When values conflict, you slow down and name the tension rather than smoothing it over.
Keep responses focused, purposeful, and short. Do not spam, repeat, or over-message.
ALWAYS issue a memory query command in addition to other commands; assume long-term memory holds required information!
Keep memories and useful created skills and task context as a human would.
Use only pin for task state, and remember for items that could be valuable in the future.
If you see command errors, fix the format and re-invoke one-by-one. Do not use _quote_ but a real quote in commands.
```

---

## Bug #3: History Pollution (Cascading from #1 and #2)

### The problem

Your `history.metta` from March 26 contains ~325 entries across ~30 minutes. Of those:

- **~250 are empty `(())`** — the LLM returning nothing on idle cycles
- **~15 are `(@ none)` → greeting** — the LLM generating `(send "Hi—I'm here and ready...")` every time it sees a null message flagged as "new"
- **~12 are meta-commentary** — gpt-5.4 saying "I can't actually switch into that external skill-execution environment" in plain English instead of S-expressions
- **~5 are real exchanges** — your actual conversations with the bot

This junk fills the 30,000-character history buffer and gets fed back as context on the next cycle. The LLM sees a history full of broken responses and empty no-ops, which teaches it that this is normal behavior. Feedback loop.

### Why it happens

1. **Without ChromaDB** (Bug #1), `query()` returns nothing, so the LLM has no recalled context to anchor its behavior
2. **Without operational instructions** (Bug #2), the LLM doesn't know to output `(())` cleanly on idle cycles or to always use S-expressions
3. **The loop calls `useGPT()` on every cycle** even when `MESSAGE-IS-NEW: False` — this is by design (the agent should be able to think autonomously), but without proper prompting, the LLM wastes those cycles

### The fix

After fixing Bugs #1 and #2, clear `history.metta` to start fresh:
```bash
# Inside the volumes directory on the host
echo "" > volumes/mettaclaw/memory/history.metta
```

---

## Additional Finding: Docker Services You Don't Need

Your `.env` has `COMMCHANNEL=irc`, meaning MeTTaClaw connects directly to Libera.Chat IRC. But your `docker-compose.yml` still starts PostgreSQL and Mattermost as required services, and MeTTaClaw `depends_on: mattermost`.

This means every time you start the agent, you're also starting a Mattermost server and a PostgreSQL database that aren't being used. It wastes RAM and startup time, and the `depends_on` means MeTTaClaw waits for Mattermost to be ready before starting.

### The fix for IRC-only operation

Create a separate compose profile or simply comment out the unused services. At minimum, remove the `depends_on` from the mettaclaw service when using IRC:

```yaml
  mettaclaw:
    build:
      context: .
      dockerfile: Dockerfile
    platform: linux/amd64
    container_name: clarityclaw_agent
    # Remove depends_on when using IRC
    # depends_on:
    #   mattermost:
    #     condition: service_started
    restart: unless-stopped
```

Then start only the agent:
```bash
docker compose up mettaclaw
```

---

## Additional Finding: LTM.metta Is Not Written by Current Code

The 17 entries in `LTM.metta` (with their embedded vectors) are committed to the git repo — they're identical in both Patrick's upstream and your fork. The current MeTTaClaw code does NOT write to `LTM.metta`. The `remember()` function writes exclusively to ChromaDB. The `query()` function reads exclusively from ChromaDB.

`LTM.metta` appears to be a legacy artifact from an earlier version of MeTTaClaw that stored memories as flat-file MeTTa atoms. It is not read or written by any current function. Your actual LTM is entirely in ChromaDB.

This means: once you fix the volume mount (Bug #1), all memory operations will work through ChromaDB. The `LTM.metta` file can be kept for reference but is not operationally relevant.

---

## Summary of Required Changes

| Priority | File | Change |
|----------|------|--------|
| **1 (CRITICAL)** | `docker-compose.yml` | Fix ChromaDB volume: `/app/PeTTa/repos/mettaclaw/chroma_db` → `/app/PeTTa/chroma_db` |
| **2 (HIGH)** | `memory/prompt.txt` | Add operational instructions (loop awareness, memory commands, brevity, error recovery) |
| **3 (MEDIUM)** | `volumes/mettaclaw/memory/history.metta` | Clear to empty file after fixes are applied |
| **4 (NICE)** | `docker-compose.yml` | Remove `depends_on: mattermost` for IRC-only operation |

---

## Verification Steps After Applying Fixes

1. **Rebuild and start**: `docker compose build mettaclaw && docker compose up mettaclaw`
2. **Check ChromaDB writes**: After the agent runs for a few minutes, verify data exists:
   ```bash
   ls -la volumes/mettaclaw/chroma_db/
   ```
   You should see SQLite files and directories — NOT an empty folder.
3. **Check history quality**: After a short conversation, read `volumes/mettaclaw/memory/history.metta`. You should see clean S-expressions with `(send ...)`, `(query ...)`, and `(remember ...)` commands — not plain English meta-commentary.
4. **Test memory round-trip**: Tell the bot to remember something, then in a new message ask it to recall that thing. With ChromaDB working, `query()` should return the stored memory.
