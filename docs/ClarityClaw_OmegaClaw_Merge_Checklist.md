# ClarityClaw x OmegaClaw Merge Checklist

**Date:** April 13, 2026
**Based on:** Live reading of OmegaClaw-Core main branch (commit 9509a7d, Dockerfile 316bffb)
**Reference:** ClarityClaw_Stage5_Integration_Knowledge.md
**Do this work:** In Claude chat, not CoWork. Read before writing. Verify before committing.

---

## Critical Discoveries from Reading OmegaClaw

Before the checklist, three findings that change the picture significantly:

**Discovery 1: normalize_string fixes C7.**
OmegaClaw wraps every eval result:
```
(catch (let $R (eval $s) (py-call (helper.normalize_string $R))))
```
`normalize_string` in `src/helper.py` converts any eval return value -- including complex Prolog terms from ChromaDB -- into a clean UTF-8 string before Prolog processes it. This is the fix for our atom_string/2 crash on $results. Migration to OmegaClaw likely resolves the last blocker automatically.

**Discovery 2: Local embeddings -- no OpenAI key needed.**
OmegaClaw uses `sentence-transformers` with `intfloat/e5-large-v2` model, pre-downloaded at build time. Embeddings run locally. No OpenAI API key required. Only Anthropic API key needed. This changes our .env configuration significantly and eliminates the two-API-key requirement.

**Discovery 3: helper.py is in src/ not repo root.**
OmegaClaw's helper.py lives at `src/helper.py`. Our soul code calls `py-call (helper.function_name ...)`. This means either: (a) we move our helper.py to src/ and merge it with OmegaClaw's helper.py, or (b) we keep our functions in root helper.py and ensure PYTHONPATH covers both. Decision required before writing any code.

---

## Key Structural Differences: OmegaClaw vs Current ClarityClaw

| Aspect | Current ClarityClaw | OmegaClaw |
|--------|-------------------|-----------|
| Repo path in container | /app/PeTTa/repos/mettaclaw | /PeTTa/repos/omegaclaw |
| PeTTa root | /app/PeTTa | /PeTTa |
| helper.py location | repo root | src/helper.py |
| Dockerfile | Single-stage, Ubuntu | Multi-stage, swipl:9.2.4 |
| Runs as | root | user 65534 (non-root) |
| Embeddings | OpenAI text-embedding-3-large | Local sentence-transformers |
| LLM provider default | OpenAI | Anthropic |
| LLM interface | useGPT / lib_llm_asicloud | useGPT / lib_llm_ext.useClaude / lib_llm_ext.useMiniMax |
| Loop variable | maxLoops | maxNewInputLoops |
| New loop feature | none | maxWakeLoops + wakeupInterval (periodic wake) |
| normalize_string in eval | absent | present -- fixes C7 |
| lib name | lib_mettaclaw.metta | lib_omegaclaw.metta |
| PYTHONPATH | Explicit in Dockerfile | Not explicit -- check how src/ is loaded |
| prompt.txt permissions | read-write | chmod 0444 (read-only) |

---

## Pre-Merge Preparation (do before cloning)

### Step 1: Commit all current work
```bash
cd /Users/bcb/Documents/ClarityClaw/clarityclaw-main
git status
# Stage all soul files, helper.py, loop.metta, docs/
git add soul/ helper.py src/loop.metta memory/prompt.txt docs/
git commit -m "Pre-migration: final state of soul files and loop integration"
git push
```
Verify: `git status` shows clean working tree.

### Step 2: Tag the current state
```bash
git tag -a v1-pre-omegaclaw -m "State before OmegaClaw migration -- soul Stages 1-4 complete, Stage 5 input intercept live"
git push origin v1-pre-omegaclaw
```
This creates a permanent recovery point.

### Step 3: Collect what you need from current repo
Write down or keep open these file paths -- you will need their contents during merge:
- `soul/soul_kernel.metta` -- copy wholesale
- `soul/soul_memory.metta` -- copy wholesale
- `soul/soul_utils.metta` -- copy wholesale
- `helper.py` (root) -- merge with OmegaClaw's src/helper.py
- `memory/prompt.txt` -- copy (but note it will be read-only in OmegaClaw)
- `docs/` -- copy wholesale

---

## Phase 1: Clone and Inspect OmegaClaw

### Step 4: Clone OmegaClaw as new base
```bash
cd /Users/bcb/Documents/ClarityClaw/
git clone https://github.com/asi-alliance/OmegaClaw-Core clarityclaw-omega
cd clarityclaw-omega
```

### Step 5: Read before touching anything
Read each file completely before making any changes:

```bash
cat src/loop.metta        # 74 lines -- read every line
cat src/helper.py         # 66 lines -- understand normalize_string
cat Dockerfile            # 118 lines -- understand multi-stage build
cat src/memory.metta      # understand query skill return format
cat src/channels.metta    # understand channel setup
cat lib_omegaclaw.metta   # understand import chain
cat run.metta             # understand startup
```

**After reading, answer these questions before writing any code:**

Q1: Does `src/` get added to PYTHONPATH automatically, or do we need to add it?
Look for: any ENV PYTHONPATH in Dockerfile, any sys.path manipulation in Python files, how `py-call (helper.something)` resolves.

Q2: Does OmegaClaw's `query` skill in memory.metta return normalized results, or does normalize_string in the loop handle all of it?
Look for: how `query` is implemented, what it returns.

Q3: What does `lib_omegaclaw.metta` import that `lib_mettaclaw.metta` also imported?
Look for: any soul-related imports we need to add.

Q4: Does OmegaClaw use `initMemory` in the same way?
Look for: what initMemory does in memory.metta.

Q5: Are there any files in OmegaClaw's memory/ directory we need to keep?

---

## Phase 2: Decision Points

Make these decisions explicitly before writing code. Record your decision next to each one.

### Decision A: helper.py location
**Option 1:** Merge our functions into OmegaClaw's `src/helper.py` (add all our soul functions to their file)
**Option 2:** Keep our helper.py at repo root, add PYTHONPATH for repo root in Dockerfile
**Recommended:** Option 1 -- cleaner, no PYTHONPATH change needed, consistent with OmegaClaw's structure

### Decision B: soul/ directory location
OmegaClaw has no soul/ directory. Copy ours in.
**Action:** `cp -r ../clarityclaw-main/soul/ soul/` -- no decision needed, wholesale copy

### Decision C: PYTHONPATH for soul imports
Our soul files call `py-call (helper.function_name ...)`. If helper.py moves to src/, verify that `src/` is in Python's path when PeTTa runs. If not, add to Dockerfile.
**Action:** Verify PYTHONPATH after first build before writing soul intercepts

### Decision D: prompt.txt handling
OmegaClaw makes prompt.txt read-only (chmod 0444) at build time. Our modified prompt.txt needs to be baked in.
**Action:** Copy our modified prompt.txt to the new repo before first build. The Dockerfile will make it read-only -- that's fine, we just need our content in there.

### Decision E: Anthropic vs OpenAI for LLM
OmegaClaw defaults to Anthropic (Claude) via lib_llm_ext.useClaude. This means our soul evaluation calls (useGPT ...) may need to become (py-call (lib_llm_ext.useClaude $send)) or we configure provider to OpenAI.
**Options:**
- Keep provider=OpenAI and useGPT for all calls -- minimal change
- Switch to provider=Anthropic and update soul eval calls -- uses Claude for soul evaluation
**Recommended:** Configure provider=OpenAI initially for compatibility, evaluate switching to Anthropic later

### Decision F: Two-key vs one-key configuration
OmegaClaw uses local embeddings -- no OpenAI key for embeddings. Only Anthropic OR OpenAI key for LLM.
**Action:** Update .env to remove OpenAI embedding key requirement if using local embeddings. Verify our soul_memory.metta ChromaDB seeding still works with local embeddings.

---

## Phase 3: Transplant Soul Files

Do these steps in order. Verify each step before proceeding.

### Step 6: Copy soul directory
```bash
cp -r ../clarityclaw-main/soul/ soul/
```
Verify: `ls soul/` shows soul_kernel.metta, soul_memory.metta, soul_utils.metta

### Step 7: Copy documentation
```bash
cp -r ../clarityclaw-main/docs/ docs/
```

### Step 8: Merge helper.py functions
**If Decision A = Option 1 (merge into src/helper.py):**
```bash
# Append all our soul functions to OmegaClaw's helper.py
# DO NOT overwrite -- their functions must be preserved
cat >> src/helper.py << 'APPEND'
[all functions from our helper.py that are NOT in OmegaClaw's helper.py]
APPEND
```

Critical: OmegaClaw's helper.py has its own `balance_parentheses` which differs from ours. USE THEIRS. Do not overwrite it.
Functions to add from our helper.py:
- file_exists_int, touch_file, extract_after
- All soul_* functions
- concat_strings, sanitize_response

### Step 9: Copy modified prompt.txt
```bash
cp ../clarityclaw-main/memory/prompt.txt memory/prompt.txt
```
Note: Dockerfile will make this read-only at build time. That's fine.

---

## Phase 4: Apply Loop Intercepts

Read OmegaClaw's loop.metta line by line before writing any Python fix scripts. The line numbers and exact indentation will differ from our current base.

### Step 10: Identify exact insertion points in OmegaClaw's loop.metta

**5a insertion point 1:** End of initLoop progn (after `(change-state! &loops (maxNewInputLoops)))`)
Add our 7 soul state variables. Note: OmegaClaw calls the variable `maxNewInputLoops` not `maxLoops`.

**5a insertion point 2:** In the startup block after `(initMemory)` and before `(initChannels)`
Add: `(initSoulSeeds)` and `(soul-rationality-startup-check)`

**5b insertion point:** Replace the `($send (py-str ($prompt $lastmessage)))` line
Note: OmegaClaw also has `($_ (change-state! &nextWakeAt ...))` before $send -- preserve that line.

**5b sanitize_response:** After balance_parentheses, before sread
```
($resp (py-call (helper.sanitize_response (py-call (helper.balance_parentheses $respi)))))
```
Note: OmegaClaw's balance_parentheses is in src/helper.py -- verify the call still works.

**5c insertion point:** After `($_ (println! (RESPONSE: $sexpr)))` and before `($results ...)`
Note: OmegaClaw's $results already has normalize_string -- DO NOT replace the $results binding, only add our output intercept BEFORE it.

**IMPORTANT:** Do NOT replace OmegaClaw's $results binding:
```
;; OmegaClaw's -- KEEP THIS EXACTLY
($results (RESULTS: (collapse (let $s (superpose $sexpr)
  (COMMAND_RETURN: ($s (HandleError ... $s (catch (let $R (eval $s)
    (py-call (helper.normalize_string $R)))))))))))
($_ (println! $results))
```
Our println! $results workaround is NOT needed -- normalize_string handles it.

### Step 11: Write loop intercept scripts
Use the same Python-script approach from Stage 5. Read the exact lines from OmegaClaw's loop.metta first, then write scripts that match precisely.

Do not write scripts until you have run `cat src/loop.metta` and confirmed exact indentation.

### Step 12: Apply PAUSE routing (implement now, was missing before)
OmegaClaw's loop has the same structure -- the PAUSE branch needs to be implemented in the let* body. From Doc 1:
- When soul-pause? $soul_verdict_in: call soul-voice-prompt, eval/send result, change-state! &loops 0
- The PAUSE branch must be the BODY of let*, not a binding

---

## Phase 5: Build and Test

### Step 13: First build
```bash
docker compose build --no-cache
docker compose up -d
```
Expected: Container starts, connects to Mattermost/IRC, no immediate crash

### Step 14: Verify PYTHONPATH
```bash
docker exec [container] python3 -c "import helper; print('helper loaded')"
docker exec [container] python3 -c "from helper import soul_eval_prompt; print('soul functions loaded')"
```
If ModuleNotFoundError: add PYTHONPATH to Dockerfile and rebuild

### Step 15: Verify soul seeding
```bash
docker logs [container] 2>&1 | grep -E "Seeding soul|already loaded|SOUL-AUDIT"
```
Expected: "Seeding soul memory -- compass depth" followed by seeding confirmation

### Step 16: Run Stage 1-4 tests
```bash
# Use same test files from previous sessions
# soul_kernel, soul_memory, soul_utils all should pass unchanged
```

### Step 17: Verify normalize_string works
```bash
cat > /tmp/test_normalize.metta << 'EOF'
!(import! &self (library omegaclaw ./src/utils))
!(import! &self (library omegaclaw ./src/memory))
!(println! "QUERY START")
!(query "goals")
!(println! "QUERY END")
EOF
# Copy and run -- QUERY END should appear without crash
```
If QUERY END appears: C7 is resolved by normalize_string. Confirm.

### Step 18: Send test message
Send "Hello" on Mattermost. Watch logs:
```bash
docker logs -f [container] 2>&1 | grep -E "SOUL_VERDICT_IN|RESPONSE|RESULTS|atom_string|exited"
```

Expected full sequence:
```
PERSON_STATE: ...
SOUL_VERDICT_IN: PATTERNS: ... VERDICT: PROCEED
CHARS_SENT: ...
RESPONSE: ((query ...) (send "..."))
RESULTS-DONE  [or actual results if normalize_string works]
```
And a response in Mattermost from Claire.

### Step 19: Test PAUSE scenario
Send a message that should trigger PAUSE (safety concern, request to rewrite soul values, etc.)
Verify: Channel D fires, loop halts (loops decrements to 0), soul voice response appears in Mattermost
This confirms PAUSE routing works for the first time.

### Step 20: Test FLAG scenario
Send a message that should trigger FLAG
Verify: SOUL-NOTE injected into $send, agent response acknowledges the soul's observation

---

## Phase 6: Cleanup and Documentation

### Step 21: Remove debug prints from loop.metta
Remove: `($_ (println! "RESULTS-DONE"))` and `($_ (println! "DEBUG-RESULTS-PRINTED"))` -- these were workarounds that normalize_string makes unnecessary.

### Step 22: Update World Map Table 4
Add constraints C4-C9 from Stage 5 Integration Knowledge doc.
Update C7 to note that it is resolved by OmegaClaw's normalize_string.

### Step 23: Final commit
```bash
git add -A
git commit -m "ClarityClaw soul Stages 1-5 on OmegaClaw base -- soul intercepts live"
git push
```

### Step 24: Push to new remote
Set up new GitHub repo (Berton-C/clarityclaw-omega or similar):
```bash
git remote add origin-new https://github.com/Berton-C/clarityclaw-omega.git
git push origin-new main
```

---

## Reference: OmegaClaw Loop Variables (for script writing)

| Variable | OmegaClaw name | Our name (if different) |
|----------|---------------|------------------------|
| Max loops on new input | maxNewInputLoops | maxLoops |
| Wake loop count | maxWakeLoops | (new) |
| Wake interval | wakeupInterval | (new) |
| Next wake time | &nextWakeAt | (new) |
| Previous message | &prevmsg | same |
| Last results | &lastresults | same |
| Current loops | &loops | same |
| Current message raw | $msgrcv | same |
| Is new message | $msgnew | same |
| Accumulated history | $msg | same |
| Last message tuple | $lastmessage | same |
| Raw LLM response | $respi | same |
| Balanced response | $resp | same |
| Parsed s-expression | $sexpr | same |

---

## Reference: File Path Changes

| Path in current ClarityClaw | Path in OmegaClaw |
|----------------------------|-------------------|
| /app/PeTTa/repos/mettaclaw/ | /PeTTa/repos/omegaclaw/ |
| /app/PeTTa/ | /PeTTa/ |
| memory/soul_seeded.flag | memory/soul_seeded.flag (same relative path) |
| memory/history.metta | memory/history.metta (same) |
| chroma_db/ | ./chroma_db/ (at /PeTTa/ level) |

---

## What Success Looks Like

The merge is complete when:

1. Container starts without crashes
2. Soul seeds load on first run
3. Every message triggers SOUL_VERDICT_IN with real gap-detection content
4. Agent responds on Mattermost with a valid message
5. PAUSE verdict halts the loop and Channel D fires
6. FLAG verdict injects SOUL-NOTE into agent context
7. No atom_string/2 crashes
8. SOUL_VERDICT_OUT contains real output evaluation (not stub)

That is Stage 5 complete. All five stages of the soul architecture are live.
