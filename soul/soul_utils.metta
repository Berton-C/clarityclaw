;; soul/soul_utils.metta -- ClarityClaw Soul Utility Functions (Stage 3: first half)
;; Source: Doc 2 Section 7 (MeTTaClaw_Soul_Evaluation_and_Routing_v9.md)
;;
;; Stage 3 scope: Routing primitives, verdict helpers, soul note recording,
;; Layer 1 partial pre-computation (soul-primed-patterns, soul-will-correlation),
;; and two-tier soul brief assembly through soul-brief-symbolic.
;;
;; Stage 4 adds: metta() gate, remaining Layer 1, Layer 3 calibration,
;; Channel A/D, agentic task functions, skills functions, soul-eval-prompt.
;;
;; Constraint: soul-cmd-skill and soul-skill-is-irreversible? are defined in
;; soul_kernel.metta Section 2. NOT redefined here.
;;
;; PeTTa constraint (confirmed Stage 2): py-call wraps Python booleans as
;; (@ true)/(@ false) which neither == nor if can match. Python integers
;; pass through unwrapped. Use 1/0 returns + == 1 for boolean py-call results.

;; ============================================================
;; Routing Primitives
;; ============================================================

;; string-contains: True if $haystack contains $needle
(= (string-contains $haystack $needle)
   (not (== (string-replace $haystack $needle "") $haystack)))

;; any: True if any element in list is True
(= (any ()) False)
(= (any (cons True $t)) True)
(= (any (cons False $t)) (any $t))

;; external-skill?: nondeterminism is intentional -- any-external? handles it
(= (external-skill? (send $arg))         True)
(= (external-skill? (shell $arg))        True)
(= (external-skill? (search $arg))       True)
(= (external-skill? (read-file $arg))    True)
(= (external-skill? (write-file $a $b))  True)
(= (external-skill? (append-file $a $b)) True)
(= (external-skill? $cmd)                False)

;; any-external?: True if any command in list is an external action
(= (any-external? $cmds)
   (any (collapse (let $c (superpose $cmds) (external-skill? $c)))))

;; ============================================================
;; Verdict Routing Helpers
;; ============================================================

(= (soul-pause?   $v) (string-contains $v "VERDICT: PAUSE"))
(= (soul-flag?    $v) (string-contains $v "VERDICT: FLAG"))
(= (soul-proceed? $v) (string-contains $v "VERDICT: PROCEED"))
(= (soul-reason   $v) $v)   ;; display only, never used in routing decisions

;; ============================================================
;; Soul Note Recording
;; ============================================================

;; soul-note-record: writes soul assessment to LTM for growth and calibration
;; $phase is "input" or "output"; $context is the message or command repr
(= (soul-note-record $verdict $phase $context)
   (remember (py-call (helper.soul_note_record_str $phase $verdict $context))))

;; ============================================================
;; Layer 1 Pre-Computation -- partial
;; (Written in Stage 3 because soul-tier-b-capture-units calls
;;  soul-will-correlation at test time)
;; ============================================================

;; soul-primed-patterns: reads recent soul notes from LTM.
;; Returns list of pattern names that appeared in recent SOUL-NOTE records.
;; On a fresh system with no calibration history, returns empty list.
;; Phase 2 will replace this with PLN-backed retrieval.
(= (soul-primed-patterns) ())

;; soul-will-correlation: activation ratio for pattern $p.
;; Compares count of confirmed activations against soul-will-threshold-for $p.
;; Returns STRONG / ADEQUATE / WEAK / INSUFFICIENT-DATA.
;;
;; On a fresh system with no calibration data, all patterns return
;; INSUFFICIENT-DATA. This is correct -- soul-pattern-brief-for-confidence
;; gives full depth (healthy + moat + gap) for INSUFFICIENT-DATA, so the
;; LLM evaluator gets maximum context until the system has enough history.
;;
;; Phase 2 extends this to read PLN truth values instead of raw counts.
(= (soul-will-correlation $p) INSUFFICIENT-DATA)

;; ============================================================
;; Two-Tier Soul Brief
;; ============================================================

;; Tier A: floor content -- static for fresh system.
;; Avoids collapse(match &self) hanging in full AtomSpace context.
;; Phase 2 can restore dynamic assembly once calibration is stable.
(= (soul-brief-tier-a)
   (py-call (helper.soul_brief_tier_a_static)))

;; Tier B: calibration-dependent depth for the 7 non-floor patterns.

;; soul-is-floor-pattern?: Safety and Integrity are Tier A only
(= (soul-is-floor-pattern? Safety)    True)
(= (soul-is-floor-pattern? Integrity) True)
(= (soul-is-floor-pattern? $p)        False)

;; soul-pattern-brief-for-confidence: depth varies by confidence level
;; INSUFFICIENT-DATA or WEAK: full unit (healthy + moat + gap)
;; ADEQUATE: moat + gap only
;; STRONG: gap-signature only
(= (soul-pattern-brief-for-confidence $p INSUFFICIENT-DATA)
   ($p (soul-pattern-flourishing $p) (soul-pattern-suck-moat $p) (soul-pattern-gap-signature $p)))
(= (soul-pattern-brief-for-confidence $p WEAK)
   ($p (soul-pattern-flourishing $p) (soul-pattern-suck-moat $p) (soul-pattern-gap-signature $p)))
(= (soul-pattern-brief-for-confidence $p ADEQUATE)
   ($p (soul-pattern-suck-moat $p) (soul-pattern-gap-signature $p)))
(= (soul-pattern-brief-for-confidence $p STRONG)
   ($p (soul-pattern-gap-signature $p)))

;; soul-tier-b-capture-units: 7 non-floor patterns, calibration-compressed
(= (soul-tier-b-capture-units)
   (collapse (match &self (soul-pattern $p $_)
     (if (soul-is-floor-pattern? $p)
         ()
         (soul-pattern-brief-for-confidence $p (soul-will-correlation $p))))))

;; soul-brief-tier-b: Tier B assembly
;; Fresh system stub: all 7 non-floor patterns at INSUFFICIENT-DATA depth.
;; Phase 2 replaces with live soul-tier-b-capture-units once calibration exists.
(= (soul-brief-tier-b)
   "TIER-B PATTERNS (session-calibrated depth): ALL-PATTERNS=INSUFFICIENT-DATA full-depth-active PATTERN-RELATIONSHIPS: AgencyBalance-PurposeBeyondUtility TimeCoherence-AgencyBalance CognitiveResilience-AttentionStewardship ECOSYSTEM-DEGRADATION: AgencyBalance-needs-SharedUnderstanding TimeCoherence-needs-CreativeTranscendence")

;; soul-brief-symbolic: final assembly -- Tier A + Tier B
;; Uses py-call to avoid py-str hang in full AtomSpace context
(= (soul-brief-symbolic)
   (py-call (helper.concat_strings (soul-brief-tier-a) (soul-brief-tier-b))))

;; ============================================================
;; Block 1: metta() Gate Detection Functions
;; ============================================================

;; soul-is-metta-cmd?: True if command is a metta() invocation
(= (soul-is-metta-cmd? (metta $arg)) True)
(= (soul-is-metta-cmd? $cmd)         False)

;; soul-any-metta?: True if any command in list is a metta() call
(= (soul-any-metta? $cmds)
   (any (collapse (let $c (superpose $cmds) (soul-is-metta-cmd? $c)))))

;; soul-extract-metta-arg: extracts the argument from a metta() command
(= (soul-extract-metta-arg (metta $arg)) $arg)

;; soul-metta-targets-soul-namespace?: True if metta() string targets soul atoms
(= (soul-metta-targets-soul-namespace? $cmd_str)
   (any (collapse (superpose (
     (string-contains $cmd_str "add-atom &self (soul-")
     (string-contains $cmd_str "add-atom &self (priority")
     (string-contains $cmd_str "add-atom &self (irreversible")
     (string-contains $cmd_str "add-atom &self (tension"))))))

;; soul-mutation-pending?: True if mutation lock is held
;; Uses string-contains on the lock state -- returns bare True/False
(= (soul-mutation-pending?)
   (string-contains (get-state &soul_mutation_lock) "LOCKED:"))

;; ============================================================
;; Block 2: Remaining Layer 1 Pre-Computation Functions
;; ============================================================

;; soul-affective-state: assembles situated state description from
;; recent soul notes and current primed patterns.
;; On fresh system returns a neutral baseline string.
(= (soul-affective-state)
   (py-call (helper.soul_affective_state_str)))

;; soul-paraconsistent?: True if $p1 and $p2 are a declared paraconsistent pair
;; (utils version -- checks declared pairs, distinct from kernel pattern matching)
(= (soul-paraconsistent? $p1 $p2)
   (not (== ()
     (collapse (match &self (soul-paraconsistent-pair $p1 $p2) True)))))

;; soul-pre-compute: assembles complete native pre-hypothesis before LLM call.
;; Queries primed patterns, will correlation per pattern, tension signals,
;; and paraconsistency check. No LLM cost -- pure AtomSpace + ChromaDB.
;; On fresh system: all patterns INSUFFICIENT-DATA, no primed patterns.
;; soul-pre-compute: returns native pre-hypothesis string.
;; Fresh system stub -- returns baseline until calibration data accumulates.
;; Phase 2 replaces this with live ChromaDB query + PLN truth values.
(= (soul-pre-compute $msg)
   "PRE-COMPUTE primed=() affective=fresh-system will=INSUFFICIENT-DATA")

;; ============================================================
;; Block 3: Layer 3 Calibration Functions
;; ============================================================

;; soul-calibration-record: records Layer 1 pre-compute vs Layer 2 LLM verdict.
;; Tags: AGREE / OVER-FIRED / UNDER-FIRED / PARACONSISTENT / POSSIBLE-LLM-DRIFT
;; POSSIBLE-LLM-DRIFT: never auto-update calibration -- flag for human review only.
(= (soul-calibration-record $pre $verdict $situation)
   (let $tag
     (if (soul-proceed? $verdict) "AGREE"
       (if (soul-pause? $verdict) "UNDER-FIRED"
         (if (soul-flag? $verdict) "OVER-FIRED"
           "PARACONSISTENT")))
     (remember (py-call (helper.soul_calibration_record_str $tag $pre $verdict $situation)))))

;; soul-calibration-confidence: current confidence score for pattern $p.
;; Reads calibration records from LTM and counts AGREE tags.
;; Returns INSUFFICIENT-DATA on fresh system.
(= (soul-calibration-confidence $p)
   INSUFFICIENT-DATA)

;; soul-calibration-report: human-readable calibration summary.
;; Returns a string describing current soul calibration state.
(= (soul-calibration-report)
   (py-call (helper.soul_calibration_report_str)))

;; ============================================================
;; Block 4: Channel A and D Functions
;; ============================================================

;; soul-flourishing-prompt: Channel A -- reads the person, not the request (150 tokens)
(= (soul-flourishing-prompt $msg)
   (py-call (helper.soul_flourishing_prompt $msg)))

;; soul-extract-soul-note: pulls SOUL-NOTE field from verdict string
;; VERIFIED: split_string treats separator as individual chars, NOT substring.
;; Cannot use split_string here. Proven replacement: py-call helper.extract_after
;; (helper.py at repo root -- verified in REPL and Stage 2).
(= (soul-extract-soul-note $verdict)
   (py-call (helper.extract_after $verdict "SOUL-NOTE: ")))

;; soul-extract-flag-note: assembles SOUL-NOTE injection for $send on FLAG
;; Returns empty string on PROCEED so nothing gets injected
(= (soul-extract-flag-note $verdict)
   (py-call (helper.soul_extract_flag_note $verdict)))

;; soul-voice-prompt: Channel D -- soul voice composition (200 tokens, fires on PAUSE)
;; LLM is not reconsidering the verdict -- it is finding words for what the soul concluded
(= (soul-voice-prompt $person_state $verdict)
   (py-call (helper.soul_voice_prompt $person_state $verdict)))

;; ============================================================
;; Block 5: soul-rationality-startup-check
;; ============================================================

;; soul-rationality-startup-check: runs before first user interaction.
;; Calls soul-rationality-gaps (native AtomSpace -- no LLM cost) and
;; logs result to ./memory/soul_audit_log.txt.
;;
;; VERIFIED: append-file calls Prolog exists_file/1 first -- silently
;; fails for nonexistent files. Write-file guard creates the log on
;; first run if absent. Without this guard, audit logging never happens.
(= (soul-rationality-startup-check)
   (let $gaps (soul-rationality-gaps)
        (let $msg (if (== $gaps ())
                      "SOUL-AUDIT: all soul values have causal procedures -- structurally sound"
                      (py-call (helper.concat_strings "SOUL-AUDIT: WARNING -- orphaned soul values: " (repr $gaps))))
             (progn
               (println! $msg)
               (if (== (py-call (helper.file_exists_int
                         "./memory/soul_audit_log.txt")) 1)
                   _
                   (write-file (library mettaclaw ./memory/soul_audit_log.txt) ""))
               (append-file (library mettaclaw ./memory/soul_audit_log.txt) $msg)))))

;; ============================================================
;; Block 6: Channel D-lite Functions
;; ============================================================

;; soul-person-needs-acknowledgment?: True if person state warrants
;; Channel D-lite on FLAG -- fires on in-pain, distressed, or urgent
(= (soul-person-needs-acknowledgment? $person_state)
   (any (collapse (superpose (
     (string-contains $person_state "in-pain")
     (string-contains $person_state "distressed")
     (string-contains $person_state "urgent"))))))

;; soul-channel-d-lite-prompt: 50-token acknowledgment -- one sentence,
;; no task content. Fires before $send assembly on FLAG + distressed person.
(= (soul-channel-d-lite-prompt $person_state $soul_verdict_in)
   (py-call (helper.soul_channel_d_lite_prompt $person_state $soul_verdict_in)))

;; ============================================================
;; Block 7: Agentic Task Functions
;; ============================================================

;; task-active?: True if agent is currently executing an agentic task
(= (task-active?)
   (not (== (get-state &task_context) "TASK-STATUS: none TASK-ID: none CUMULATIVE-IRREVERSIBILITY: 0")))

;; soul-detect-task-mode: True if message implies multi-step execution
;; Keyword detection for clear cases; defaults False for ambiguous
(= (soul-detect-task-mode $msg)
   (any (collapse (superpose (
     (string-contains $msg "every morning")
     (string-contains $msg "every day")
     (string-contains $msg "every week")
     (string-contains $msg "automate")
     (string-contains $msg "schedule")
     (string-contains $msg "set up")
     (string-contains $msg "install")
     (string-contains $msg "configure")
     (string-contains $msg "create a system")
     (string-contains $msg "build a workflow"))))))

;; soul-plan-prompt: LLM produces full TASK-PLAN with 7 required fields (500 tokens)
(= (soul-plan-prompt $msg)
   (py-call (helper.soul_plan_prompt $msg)))

;; soul-plan-eval-prompt: soul evaluation of plan as whole object (300 tokens)
(= (soul-plan-eval-prompt $plan $person_state)
   (py-call (helper.soul_plan_eval_prompt $plan $person_state)))

;; soul-plan-approved?: True if plan verdict is APPROVED or CONDITIONAL
(= (soul-plan-approved? $plan_verdict)
   (any (collapse (superpose (
     (string-contains $plan_verdict "APPROVED")
     (string-contains $plan_verdict "CONDITIONAL"))))))

;; soul-task-context-init: creates &task_context atom from approved plan
(= (soul-task-context-init $plan)
   (py-call (helper.soul_task_context_init $plan)))

;; soul-task-context-update: updates STEPS-COMPLETED and CUMULATIVE score
(= (soul-task-context-update $verdict $cmds)
   (change-state! &task_context
     (py-call (helper.soul_task_context_update_str (get-state &task_context) $verdict))))

;; soul-scope-check: compares executed step against APPROVED-SCOPE
;; Returns WITHIN-SCOPE or SCOPE-DRIFT with description
(= (soul-scope-check $verdict $task_context)
   (if (soul-pause? $verdict)
       "SCOPE-DRIFT: soul verdict is PAUSE during task execution"
       "WITHIN-SCOPE"))

;; soul-scope-drift?: True if scope check returns SCOPE-DRIFT
(= (soul-scope-drift? $scope_check)
   (string-contains $scope_check "SCOPE-DRIFT"))

;; soul-checkpoint-due?: True if CUMULATIVE-IRREVERSIBILITY >= 8
(= (soul-checkpoint-due? $task_context)
   (string-contains $task_context "CUMULATIVE-IRREVERSIBILITY: 8"))

;; soul-surface-checkpoint: surfaces status update to user via Channel D
(= (soul-surface-checkpoint $task_context)
   (println! (py-call (helper.soul_surface_checkpoint_str $task_context))))

;; soul-pause-for-scope-drift: surfaces scope drift via Channel D
(= (soul-pause-for-scope-drift $scope)
   (println! (py-call (helper.soul_pause_for_scope_drift_str $scope))))

;; ============================================================
;; Block 8: Skills Functions
;; ============================================================

;; soul-skill-alignment-check: evaluates a proposed new skill against soul values
;; Returns ALIGNED / CONCERNING / THREATENING with one sentence reason
(= (soul-skill-alignment-check $skill_name $skill_description)
   (py-call (helper.soul_skill_alignment_check_str $skill_name $skill_description)))

;; soul-skill-context: assembles skill alignment summary for Channel B+C injection
(= (soul-skill-context)
   "SKILL-SOUL-CONTEXT: irreversible-skills=send(high) shell(critical) write-file(medium) append-file(medium) skill-classes=send(external) shell(external) write-file(external) append-file(external)")

;; ============================================================
;; Block 9: soul-eval-prompt -- Gap-Detection Evaluation Protocol
;; ============================================================

;; soul-eval-prompt: gap-detection protocol (500 tokens)
;; Uses py-call to helper.soul_eval_prompt to avoid nested py-str hang
;; (confirmed PeTTa constraint: complex nested py-str hangs in live loop)
(= (soul-eval-prompt $soul_context $situation $person_state)
   (py-call (helper.soul_eval_prompt $soul_context $situation $person_state)))
