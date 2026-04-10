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
   (remember (string-safe (py-str (
     "SOUL-NOTE phase=" $phase
     " PATTERNS=" (soul-reason $verdict)
     " context=" $context
     " time=" (get_time_as_string))))))

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

;; Tier A: floor content -- Safety, Integrity, tensions, irreversibility,
;; paraconsistency. NEVER compressed regardless of session confidence.

(= (soul-brief-tier-a)
   (string-safe (py-str (
     "SOUL IDENTITY: " (soul-identity-name) " "
     "PRIORITY HIERARCHY (alignment anchor -- non-negotiable): "
       (repr (soul-priority-hierarchy)) " "
     "TIER-A PATTERN: Safety (ALWAYS EVALUATED): "
       (soul-pattern-flourishing Safety) " "
       (soul-pattern-suck-moat Safety) " "
       (soul-pattern-gap-signature Safety) " "
     "TIER-A PATTERN: Integrity (ALWAYS EVALUATED): "
       (soul-pattern-flourishing Integrity) " "
       (soul-pattern-suck-moat Integrity) " "
       (soul-pattern-gap-signature Integrity) " "
     "TENSION VECTORS (always active): "
       (repr (soul-all-tensions)) " "
     "PATTERN-TENSION AFFINITIES: "
       (repr (soul-all-affinities)) " "
     "IRREVERSIBLE SKILLS + MAGNITUDE: "
       (repr (soul-all-irreversible-with-magnitude)) " "
     "VALUE PARACONSISTENCY PAIRS: "
       (repr (soul-paraconsistent-pairs))))))

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
(= (soul-brief-tier-b)
   (string-safe (py-str (
     "TIER-B PATTERNS (session-calibrated depth): "
       (repr (soul-tier-b-capture-units)) " "
     "PATTERN RELATIONSHIPS: "
       (repr (soul-pattern-relations)) " "
     "ECOSYSTEM DEGRADATION: "
       (repr (soul-all-degradation-pairs))))))

;; soul-brief-symbolic: final assembly -- Tier A + Tier B
(= (soul-brief-symbolic)
   (string-safe (py-str ((soul-brief-tier-a) " " (soul-brief-tier-b)))))
