;; soul/test_soul_utils.metta
;; Stage 3 test harness: soul_utils.metta first half through soul-brief-symbolic.
;;
;; Import chain: utils + memory first (progn compilation fix from Stage 2),
;; then soul_kernel, then soul_utils.
;;
;; Run: docker exec clarityclaw_agent sh /app/PeTTa/run.sh \
;;        /app/PeTTa/repos/mettaclaw/soul/test_soul_utils.metta default

;; Full import chain (same order that worked for Stage 2)
!(import! &self (library mettaclaw ./src/utils))
!(import! &self (library mettaclaw ./src/memory))
!(import! &self (library mettaclaw ./soul/soul_kernel))
!(import! &self (library mettaclaw ./soul/soul_utils))

;; T1: string-contains
!(string-contains "hello world" "world")

;; T2-T4: verdict routing
!(soul-pause? "VERDICT: PAUSE reason: test")
!(soul-flag? "VERDICT: FLAG reason: test")
!(soul-proceed? "VERDICT: PROCEED")

;; T5: soul-brief-tier-a (long string with Safety, Integrity, tensions, etc.)
!(soul-brief-tier-a)

;; T6: soul-brief-tier-b (7 non-floor patterns at INSUFFICIENT-DATA depth)
!(soul-brief-tier-b)

;; T7: soul-brief-symbolic (final assembly Tier A + Tier B)
!(soul-brief-symbolic)
