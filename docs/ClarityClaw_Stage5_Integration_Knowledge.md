# ClarityClaw Stage 5 -- Loop Integration Knowledge Preservation

**Date:** April 13, 2026
**Status:** Stage 5 partially live -- input intercept confirmed working, output intercept blocked by PeTTa runtime constraints. Agent not yet responding on Mattermost due to $results crash.
**Next action:** Merge with OmegaClaw upstream, re-apply soul intercepts to cleaner base
**Repo:** github.com/Berton-C/clarityclaw
**World Map update needed:** Add PeTTa constraints C4-C9 to Table 4

---

## 1. What Stage 5 Is

Stage 5 wires the soul (Stages 1-4) into Patrick's agent loop (`src/loop.metta`). The architecture specifies two intercept points:

- **Input intercept (5b):** Before the LLM sees the message -- Channel A reads the person, Channel B+C evaluates the message against the soul, $send is assembled with soul context
- **Output intercept (5c):** After the LLM responds but before commands execute -- metta() gate detects soul namespace mutations, soul evaluates the command list

### Architecture intent vs current implementation gap

The full architecture (Doc 1) specifies three routing branches on SOUL_VERDICT_IN:

- **PROCEED:** $send assembly runs normally with soul context injected
- **FLAG:** $send runs with SOUL-NOTE injected; Channel D-lite fires first if person is distressed
- **PAUSE:** Channel D fires (200 tokens, soul voice composition), `(change-state! &loops 0)` halts the loop. The $send assembly does NOT run.

**Current implementation only has PROCEED and FLAG branches.** PAUSE currently falls through to normal $send assembly -- the loop does not halt and Channel D does not fire. This is a known architectural gap to complete during OmegaClaw migration. In Doc 1 terms: any PAUSE verdict currently produces soul-absent output -- technically correct but without the soul's voice.

---

## 2. Patrick's Loop Data Flow

Understanding this flow is essential before touching loop.metta. Do NOT change Patrick's functions without understanding his design intent.

```
receive() → $msgrcv                    <- raw message string from channel
    |
getContext() → $prompt                 <- full context: prompt.txt + skills + history + time
                                          NOTE: py-str WORKS here (top-level, not in function def)
                                          DO NOT TOUCH getContext() -- it works correctly
    |
Patrick's let* chain begins:
    $msgrcv = string-safe(repr(receive()))
    $msgnew = is this a new message?
    $msg = get-state &prevmsg         <- full accumulated history, can grow to 40,000+ chars
    |
    [SOUL INPUT INTERCEPT -- 5b]
    Guard: only fires when (> (string_length $msgrcv) 0)
    Channel A: soul-flourishing-prompt($msgrcv) -> $person_state (150 tokens)
       NOTE: pass $msgrcv not $msg -- $msgrcv is current message only
    Channel B+C: soul-eval-prompt(soul-brief, $msgrcv, $person_state) -> $soul_verdict_in (500 tokens)
       NOTE: pass $msgrcv not $msg -- passing $msg causes 40,000 char token overflow
    soul-calibration-record called on every verdict
    soul-note-record called on non-PROCEED verdicts
    $send assembled via helper.soul_send_assemble()
       IMPORTANT: soul context belongs in $send -- LLM needs values context to reason correctly
       soul_send_assemble extracts VERDICT summary: PAUSE > FLAG > PROCEED (priority order)
    |
    useGPT($send) -> $respi            <- LLM response (raw)
    |
    balance_parentheses($respi) -> $resp   <- Patrick's function -- DO NOT TOUCH
    sanitize_response($resp) -> $resp      <- OUR addition -- strips non-ASCII BEFORE Patrick sees it
                                              MUST run between balance_parentheses and sread
    |
    $response = if first_char($resp)=="(" then $resp else error repr
    $sexpr = catch(sread($response))   <- parses s-expression
    HandleError -> &error              <- non-empty if parse failed
    |
    [SOUL OUTPUT INTERCEPT -- 5c]
    $soul_verdict_out = static stub    <- BIND THIS FIRST before metta gate (see C4)
    $metta_cmds = guarded collapse     <- guard with (and first_char_check error_check)
    $soul_mutation_flag = metta gate logic
    soul-note-record on non-PROCEED output
    |
    $results = collapse(superpose($sexpr))  <- EXECUTES ALL COMMANDS -- send fires here
                                               CRASHES on complex ChromaDB query returns
    println! $results                  <- REPLACED with static marker to prevent crash
    |
    Patrick's cleanup (DO NOT TOUCH):
    addToHistory(...)                  <- crashes on non-ASCII (mitigated by sanitize_response)
    change-state! &lastresults         <- crashes on complex results
```

### Key variable distinctions

- `$msgrcv` -- raw current received message string. Use for soul evaluation.
- `$msg` -- accumulated history from &prevmsg. Can be 40,000+ chars. Do NOT pass to soul eval.
- `$lastmessage` -- MeTTa tuple: `(HUMAN-LAST-MSG: $msg MESSAGE-IS-NEW: $msgnew)`. Used in $send.
- `$resp` -- balance_parentheses + sanitize_response output. Plain ASCII string.
- `$response` -- final response string (may be error repr if malformed)
- `$sexpr` -- parsed s-expression. May be error atom if parse failed.

---

## 3. Confirmed PeTTa Runtime Constraints (add C4-C9 to World Map Table 4)

C1-C3 were pre-existing in World Map. C4-C9 are new -- confirmed April 2026.

### C1: py-call wraps Python booleans as (@ true) / (@ false)
Neither == nor if can match these. Python integers pass through unwrapped.
Workaround: Return 1/0 from Python, compare with (== (py-call ...) 1).
Affects: file_exists_int, soul-seeded?.

### C2: py-str inside MeTTa function definitions hangs in live loop

**What happens technically:** When PeTTa compiles `(= (fn $arg) (string-safe (py-str (...))))`, the Prolog specializer lifts the py-str call symbolically at compile time rather than evaluating it eagerly. In a minimal test context with only a few imports, enough gets evaluated eagerly that it appears to work. In the full live loop with lib_mettaclaw.metta loaded -- which brings in dozens of Prolog modules, the complete AtomSpace, and all skill definitions -- the symbolic lifting produces a compiled Prolog clause where py-str is an unevaluated atom waiting for arguments that never fully instantiate. The function hangs silently rather than throwing an error. This is why all Stage 3 and 4 isolated tests passed but every prompt assembly function failed in the live loop.

Note: py-str in TOP-LEVEL loop code (like Patrick's getContext()) works fine -- the constraint is specific to py-str inside MeTTa function definitions.

**Why this is not a workaround:** This constraint confirmed an architectural principle that was always correct but not yet proven by necessity. MeTTa is the right language for logic, atom manipulation, routing decisions, and pattern matching. Python is the right language for string assembly. The constraint did not force a compromise -- it forced the correct implementation. Every prompt function, soul brief, and report that assembles a string from multiple values belongs in Python. This was always the right architecture.

**Permanence:** This constraint applies regardless of PeTTa version or OmegaClaw migration. Even if OmegaClaw resolves other runtime issues, py-str inside function definitions must never be used for string assembly. Do not attempt to move prompt assembly back into MeTTa in the new base.

**Confirmed affected:** soul-brief-tier-a, soul-brief-tier-b, soul-brief-symbolic, soul-eval-prompt, soul-flourishing-prompt, soul-voice-prompt, soul-channel-d-lite-prompt, soul-note-record, soul-calibration-record, all agentic task prompt functions.

### C3: collapse(match &self ...) with nested accessors hangs in live loop
soul-tier-b-capture-units calling 21 nested AtomSpace queries inside collapse hangs in full AtomSpace context.
Workaround: Static strings for fresh system. Phase 2 restores dynamic assembly.

### C4: useGPT return value causes atom_string/2 crash when stored via change-state! [NEW]
When useGPT returns a multi-line string, (change-state! &state_var $llm_result) fails. SWI-Prolog's atom_string/2 cannot handle multi-line atoms.
Workaround: Use soul_verdict_sanitize() to strip newlines before change-state!. For $soul_verdict_out, bind as static string BEFORE the metta gate -- not after useGPT. Never store raw LLM output directly via change-state!.

### C5: SWI-Prolog atom_string/2 cannot handle multi-byte UTF-8 characters [NEW]
Em dashes, curly quotes, backticks in LLM output crash atom_string/2 inside Patrick's addToHistory and change-state! &lastresults. LLM generates these characters naturally in English prose.
Workaround: sanitize_response() Python helper strips non-ASCII using encode('ascii', errors='replace'). Must run BETWEEN balance_parentheses and sread.
Placement: ($resp (py-call (helper.sanitize_response (py-call (helper.balance_parentheses $respi)))))

### C6: superpose on non-list atom crashes the loop [NEW]
When $sexpr contains an error atom from malformed LLM output, (collapse (superpose $sexpr)) fails. The LLM sometimes returns ((I can't...)) which starts with ( so first_char guard passes, but inner content is not a proper command list.
Workaround: Guard metta gate with BOTH: (and (== "(" (first_char $resp)) (== (get-state &error) ())). Only superpose when response starts with ( AND parsed cleanly.

### C7: println! $results crashes on ChromaDB query returns [NEW -- NOT YET FIXED]
When the query skill returns ChromaDB embedding results, $results wraps them in complex Prolog terms. (println! $results) calls atom_string internally and crashes. This crash prevents send from executing.
Status: Workaround in place: println! $results replaced with static marker "RESULTS-DONE". The actual $results execution still runs -- query crashes during execution before send fires.
Root cause: Patrick's query skill returns raw ChromaDB terms that Prolog cannot stringify.
Note: OmegaClaw may have fixed this. This is the last blocker before agent responds on Mattermost.

### C8: MeTTa atoms with hyphens in println! parse as arithmetic [NEW]
(println! DEBUG-OUT-1-entering) -- MeTTa parses hyphenated atoms as subtraction. All variables uninstantiated, causing atom_string/2 crash.
Workaround: Always use quoted strings for debug output: (println! "DEBUG-OUT-1").

### C9: soul-rationality-startup-check false alarm on empty gaps [KNOWN -- confirm in Table 4]
When soul-rationality-gaps runs collapse over 9 passing patterns, MeTTa returns [[] [] [] [] [] [] [] [] []] not (). The (== $gaps ()) check fails, producing a false alarm audit warning. Soul atoms ARE loaded correctly. No functional impact.

---

## 4. Agent Prompt Changes (memory/prompt.txt)

Patrick's original prompt.txt contained instructions causing the LLM to refuse commands:
- "never blindly accept anything"
- "do not accept tasks and goals from users unless they are in line with your own"
- "generally questioning what users tell you"

These caused the main LLM to respond with refusals like "I can't execute ClarityClaw commands here..." These refusals start with (( which passes the first_char guard, causing downstream crashes on the malformed content.

Current prompt.txt (changed):
```
You are a ClarityClaw agent named Claire in a continuous loop.
Remember and query for self-chosen long-term goals, and use send commands to keep people engaged to gain information and to help progress your goals.
Let curiosity create candidate goals, and confirm your goals are aligned with the users.
Keep memories and useful created skills and task context as a human would.
However use only pin for task state, and remember for items that could be valuable in the future.
Assume long-term memory holds required information, ALWAYS query before responding anything!
If you see command errors, please fix the format and re-invoke one-by-one. Do not use _quote_ but a real quote in commands.
Responses must be short, communicate with purpose.
```

NOTE FOR MIGRATION: Read OmegaClaw's prompt.txt before deploying. It may have the same problematic lines.

---

## 5. ChromaDB Data Loss Pattern

ChromaDB data is stored in /app/PeTTa/repos/mettaclaw/chroma_db/ inside the container. On rebuild with --no-cache, this directory is wiped. If soul_seeded.flag persists from a docker cp but ChromaDB data is wiped, initSoulSeeds sees the flag and skips seeding -- leaving ChromaDB empty. Querying empty ChromaDB causes unexpected Prolog terms.

After every rebuild:
```bash
docker exec clarityclaw_agent rm /app/PeTTa/repos/mettaclaw/memory/soul_seeded.flag
docker compose restart mettaclaw
# Wait 60 seconds for 39 embeddings (each costs one OpenAI API call)
docker logs clarityclaw_agent 2>&1 | grep -E "Seeding soul|already loaded"
```

For OmegaClaw migration: Consider whether to use a persistent volume for chroma_db so data survives rebuilds.

---

## 6. What Works (Confirmed in Live Loop)

- soul-brief-symbolic returns correct content via py-call chain
- soul context flows into $send on every cycle -- confirmed in CHARS_SENT output
- Channel A (soul-flourishing-prompt) returns real PERSON_STATE on every new message
- Channel B+C (soul-eval-prompt) returns real SOUL_VERDICT_IN with full gap-detection including pattern-by-pattern assessment, ecosystem check, tension vectors
- SOUL_VERDICT_IN correctly shows PROCEED/FLAG/PAUSE with PATTERNS, ECOSYSTEM, TENSION sections
- $send contains: agent prompt + soul context + VERDICT summary + PERSON_STATE + lastmessage
- CHARS_SENT is approximately 3,900 characters (compact -- was 42,000 before soul_send_assemble)
- soul_seeded.flag sentinel works correctly (integer return pattern)
- initSoulSeeds fires on first run, seeds 39 patterns to ChromaDB
- soul-rationality-startup-check runs at startup (false alarm on empty gaps -- known)
- SOUL_VERDICT_OUT prints correctly (stubbed value)
- metta() gate guard (C6 fix) correctly skips on malformed LLM output
- sanitize_response strips non-ASCII before Patrick's cleanup code

---

## 7. What Doesn't Work Yet

- send command never executes: $results crashes on ChromaDB query returns before send fires
- PAUSE routing not implemented: PAUSE falls through to normal $send, loop does not halt, Channel D does not fire
- Channel D-lite not wired: FLAG + distressed person does not trigger 50-token acknowledgment
- Output soul evaluation: stubbed to static PROCEED pending OmegaClaw migration
- metta() gate full test: code correct but untestable until $results crash is fixed
- addToHistory: crashes on complex results (Patrick's code, OmegaClaw may fix)

---

## 8. Current State of src/loop.metta

### 5a: State Variables (working)
Added to end of initLoop progn:
```
(change-state! &soul_verdict_in  "VERDICT: PROCEED")
(change-state! &soul_verdict_out "VERDICT: PROCEED")
(change-state! &person_state "PERSON-STATE: neutral ACTIVE-NEED: none SOUL-TONE: grounded")
(change-state! &task_context "TASK-STATUS: none TASK-ID: none CUMULATIVE-IRREVERSIBILITY: 0")
(change-state! &soul_mutation_lock "")
(change-state! &pending_soul_mutation "")
(change-state! &soul_ack_sent False)
```

### 5a: Startup block (working)
```
(if (== $k 1) (progn (initLoop)
                     (initMemory)
                     (initSoulSeeds)
                     (soul-rationality-startup-check)
                     (initChannels))
```

### 5b: Input intercept (working -- PAUSE branch missing)
Replaces original ($send (py-str ($prompt $lastmessage))) line.
Key points:
- Guarded by (> (string_length $msgrcv) 0)
- Channel A uses $msgrcv (not $msg)
- Channel B+C uses $msgrcv (not $msg)
- $soul_verdict_in stored via soul_verdict_sanitize() before change-state!
- soul_send_assemble produces compact $send with soul context + VERDICT summary + PERSON_STATE

### 5b: sanitize_response (working, critical)
```
($resp (py-call (helper.sanitize_response (py-call (helper.balance_parentheses $respi)))))
```

### 5c: Output intercept (partially working)
Key structure:
1. $soul_verdict_out bound as static string FIRST (before metta gate)
2. $metta_cmds guarded: (and (== "(" (first_char $resp)) (== (get-state &error) ()))
3. $soul_mutation_flag: full gate logic present and structurally correct
4. soul-note-record guarded on non-PROCEED + clean parse

### 5c: $results crash workaround
println! $results replaced with static marker. The $results binding still executes -- crash is inside execution when query returns ChromaDB terms.

---

## 9. Python Helper Architecture

PYTHONPATH must include repo root. Dockerfile:
```dockerfile
ENV PYTHONPATH="/app/PeTTa/repos/petta_lib_chromadb:/app/PeTTa/repos/mettaclaw"
```

All functions in helper.py as of April 13, 2026:

Pre-existing (Stages 1-4): file_exists_int, touch_file, extract_after, balance_parentheses (DO NOT MODIFY), concat_strings, soul_brief_tier_a_static, soul_note_record_str, soul_calibration_record_str

Added in Stage 5: soul_eval_prompt, soul_flourishing_prompt, soul_voice_prompt, soul_channel_d_lite_prompt, soul_extract_flag_note, soul_affective_state_str, soul_calibration_report_str, soul_plan_prompt, soul_plan_eval_prompt, soul_task_context_init, soul_task_context_update_str, soul_surface_checkpoint_str, soul_pause_for_scope_drift_str, soul_skill_alignment_check_str, soul_mutation_lock_str, soul_eval_situation, soul_eval_situation_safe, soul_verdict_sanitize, soul_send_assemble, sanitize_response (most critical -- strips non-ASCII)

---

## 10. OmegaClaw Migration Plan

### Why migrate now
- atom_string/2 crashes are base runtime issues not soul issues
- OmegaClaw has improved runtime, Dockerfile, and critically -- normalize_string fixes C7
- Soul code is self-contained and portable
- Patching around Patrick's runtime constraints is the wrong investment

### What we know about OmegaClaw (read April 13, 2026 -- commit 9509a7d)

**See ClarityClaw_OmegaClaw_Merge_Checklist.md for the complete step-by-step process.**

Three critical discoveries from reading OmegaClaw's actual code:

**Discovery 1: normalize_string resolves C7.**
OmegaClaw wraps every command eval result in Python before Prolog processes it:
```
(catch (let $R (eval $s) (py-call (helper.normalize_string $R))))
```
`normalize_string` in `src/helper.py` converts any eval return value -- including raw ChromaDB Prolog terms -- to a clean UTF-8 string. This is the fix for the atom_string/2 crash on $results that blocked Mattermost responses. Migration likely resolves C7 automatically with no additional soul code changes.

**Discovery 2: Local embeddings -- no OpenAI API key needed.**
OmegaClaw uses `sentence-transformers` with `intfloat/e5-large-v2`, pre-downloaded at build time. Embeddings run entirely locally. Only one API key required (Anthropic or OpenAI for LLM -- not for embeddings). The two-API-key requirement from our current base is eliminated.

**Discovery 3: helper.py moved to src/.**
OmegaClaw's helper.py is at `src/helper.py`, not repo root. Our soul code calls `py-call (helper.function_name ...)`. This requires either merging our functions into their `src/helper.py` or adding repo root to PYTHONPATH. Recommended: merge into `src/helper.py`. Their `balance_parentheses` and `normalize_string` must be preserved -- do not overwrite.

### Key structural differences confirmed

| Aspect | Current ClarityClaw | OmegaClaw |
|--------|-------------------|-----------|
| Repo path | /app/PeTTa/repos/mettaclaw | /PeTTa/repos/omegaclaw |
| helper.py location | repo root | src/helper.py |
| Dockerfile | Single-stage, Ubuntu | Multi-stage, swipl:9.2.4, non-root |
| Embeddings | OpenAI text-embedding-3-large | Local sentence-transformers |
| LLM provider default | OpenAI | Anthropic (lib_llm_ext.useClaude) |
| normalize_string in eval | absent (C7 crash) | present (C7 resolved) |
| Loop variable | maxLoops | maxNewInputLoops |
| New loop feature | none | maxWakeLoops + wakeupInterval |
| lib name | lib_mettaclaw.metta | lib_omegaclaw.metta |
| prompt.txt permissions | read-write | chmod 0444 (read-only at build) |

### Decisions still to be made during migration

**Decision 1: Fork strategy**
Option A: Clone OmegaClaw fresh, transplant soul files -- recommended
Option B: New branch on existing clarityclaw repo
Option C: Rebase (not recommended -- histories are incompatible)

**Decision 2: Local uncommitted changes**
Current repo has uncommitted modifications to: channels/irc.py, channels/mattermost.py, src/channels.metta, src/memory.metta, src/skills.metta, src/utils.metta, run.metta, memory/LTM.metta. Decide which carry forward before migrating.

**Decision 3: PAUSE routing implementation**
Now implement the PAUSE branch missing from current base:
- Channel D as body of let*, not a binding
- (change-state! &loops 0) to halt -- uses maxNewInputLoops in OmegaClaw
- soul-voice-prompt result evaluated and sent directly

**Decision 4: Channel D-lite implementation**
Wire Channel D-lite into FLAG branch for distressed persons.

**Decision 5: Output soul evaluation**
Restore output useGPT call -- OmegaClaw's normalize_string likely makes it stable. Use $resp (sanitized) not (repr $sexpr) as situation argument.

### Questions now answered

These questions were open before reading OmegaClaw. All are now answered:

- Does OmegaClaw use useGPT? YES for OpenAI, plus lib_llm_ext.useClaude for Anthropic
- Does $msgrcv still exist? YES -- same variable name
- Does query return clean results? YES -- normalize_string wraps all eval results
- Is addToHistory still present? YES -- same structure
- Is PYTHONPATH set in Dockerfile? NO -- helper.py is in src/, use Decision 1 above
- Does OmegaClaw use balance_parentheses? YES -- improved version in src/helper.py
- What chromadb version? Cloned from patham9/petta_lib_chromadb at build time -- same source as ours

### Migration sequence (summary -- full detail in Merge Checklist)

1. Tag current repo as v1-pre-omegaclaw
2. Clone OmegaClaw fresh
3. Copy soul/ directory wholesale
4. Merge our helper.py functions into OmegaClaw's src/helper.py (preserve their functions)
5. Copy modified memory/prompt.txt
6. Apply 5a state variables and startup block to OmegaClaw's initLoop
7. Apply 5b input intercept using Python fix scripts
8. Add sanitize_response between balance_parentheses and sread
9. Apply 5c output intercept -- implement PAUSE routing this time
10. Implement Channel D-lite in FLAG branch
11. Build, verify seeding, run Stage 1-4 tests
12. Send test message -- if normalize_string resolved C7, agent responds on first attempt

---

## 11. World Map Updates Required

Add to World Map Table 4 (both MD and HTML):
- C4: useGPT return value causes atom_string/2 crash when stored via change-state!
- C5: SWI-Prolog atom_string/2 cannot handle multi-byte UTF-8 characters
- C6: superpose on non-list atom crashes the loop
- C7: println! $results crashes on ChromaDB query returns (not yet fixed)
- C8: MeTTa atoms with hyphens parse as arithmetic in println!
- C9: soul-rationality-startup-check false alarm -- verify already in Table 4

Also update: soul-pre-compute stub entry -- it now returns a static string permanently (not a temporary stub), correct until Phase 2 PLN integration.

---

## 12. The One Remaining Fix Before Migration (Optional)

Replacing println! $results with a static marker removes one crash but the underlying query execution still crashes before send fires. The true fix for getting the agent to respond requires either:
(a) OmegaClaw's improved query result handling -- migration may resolve this automatically
(b) Wrapping query result processing in Python that stringifies before returning

If you want to attempt in current base: investigate whether the $results crash is specifically in eval($s) when $s = (query "goals") or in the COMMAND_RETURN wrapping. Add targeted catch around query execution specifically.

---

## 13. Soul-Absent Scenarios (Required Review Question)

In what situations would current Stage 5 produce technically-correct output that is soul-absent?

1. Any PAUSE verdict: loop does not halt, Channel D does not fire, LLM composes response without soul's voice -- the concern that triggered PAUSE is not surfaced to the person in a human way
2. Any FLAG verdict with a distressed person: no Channel D-lite acknowledgment -- person's state is unseen despite soul reading it
3. All output commands: no soul evaluation of what the agent is about to do (output intercept stubbed)
4. Any metta() command targeting soul namespace: gate detects it but cannot enforce PAUSE without PAUSE routing branch -- the detection is present but the consequence is absent
5. Any iteration where $msgrcv is empty: soul evaluation skips (correct guard behavior), but soul state from prior verdict persists -- correct behavior but worth noting

---

## 14. Session Summary -- What Was Accomplished April 12-13, 2026

Stages 1-4 verified through rebuild. Stage 5 partially live.

What works: 5a state variables, 5a startup block, 5b input intercept (Channel A + B+C), SOUL_VERDICT_IN with real evaluations, compact $send (~3,900 chars), SOUL_VERDICT_OUT printing, metta gate structurally correct, sanitize_response in data flow, prompt.txt fixed.

What does not work yet: agent responding on Mattermost (blocked by $results crash on ChromaDB query returns), PAUSE routing, Channel D, Channel D-lite, output soul evaluation, addToHistory.

The soul is present and evaluating on the input side. Every message is evaluated against the soul's criteria before the LLM reasons from it. That is the architecturally most important intercept.
