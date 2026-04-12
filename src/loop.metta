(= (maxLoops) (empty))
(= (sleepInterval) (empty))
(= (LLM) (empty))
(= (maxOutputToken) (empty))
(= (reasoningMode) (empty))
(= (provider) (empty))

(= (initLoop)
   (progn (configure maxLoops 50) ;20
          (configure sleepInterval 1) ;10
          (configure LLM gpt-5.4)
          (configure provider OpenAI) ;OpenAI or ASICloud
          (configure maxOutputToken 6000)
          (configure reasoningMode medium)
          (change-state! &prevmsg "")
          (change-state! &lastresults "")
          (change-state! &loops (maxLoops))
          ;; ClarityClaw soul state variables
          (change-state! &soul_verdict_in  "VERDICT: PROCEED")
          (change-state! &soul_verdict_out "VERDICT: PROCEED")
          (change-state! &person_state "PERSON-STATE: neutral ACTIVE-NEED: none SOUL-TONE: grounded")
          (change-state! &task_context "TASK-STATUS: none TASK-ID: none CUMULATIVE-IRREVERSIBILITY: 0")
          (change-state! &soul_mutation_lock "")
          (change-state! &pending_soul_mutation "")
          (change-state! &soul_ack_sent False)))

(= (getContext)
   (string-safe (py-str ("PROMPT: " (getPrompt) " SKILLS: " (getSkills)
                         " OUTPUT_FORMAT: Output a ((skillName1 args1) (skillName2 args2) (skillName3 args3) (skillName4 args4) (skillName5 args5)) S-expression of up to 5 sexpr commands, double-check the parentheses it must be (cmd1 ... cmdn)!"
                         " each arg is an explicit string hence needs quotes, and variables are forbidden!"
                         " LAST_SKILL_USE_RESULTS: " (last_chars (get-state &lastresults) (maxFeedback)) " HISTORY: " (getHistory) " TIME: " (get_time_as_string)))))

(= (HandleError $msg $cmd $sexpr)
   (case $sexpr (((Error $a $b) (let $new (append (get-state &error) (($msg $cmd)))
                                          (change-state! &error $new)))
                 ($else $sexpr))))

(= (mettaclaw)
   (mettaclaw 1))
(= (mettaclaw $k)
   (progn (if (== $k 1) (progn (initLoop)
                               (initMemory)
                               (initSoulSeeds)
                               (soul-rationality-startup-check)
                               (initChannels))
                        (change-state! &loops (- (get-state &loops) 1)))
          (let $prompt (getContext)
               (progn (println! (---------iteration $k))
                      (let* (($msgrcv (string-safe (repr (receive))))
                             ($msgnew (prog1 (and (> (string_length $msgrcv) 0) (!= $msgrcv (get-state &prevmsg)))
                                             (if (> (string_length $msgrcv) 0) (change-state! &prevmsg $msgrcv) _)))
                             ($msg (get-state &prevmsg))
                             ($_ (if (and (> $k 1) $msgnew)
                                     (change-state! &loops (maxLoops)) _)))
                            (if (> (get-state &loops) 0)
                                (let* (($lastmessage (HUMAN-LAST-MSG: $msg
                                                      MESSAGE-IS-NEW: $msgnew))
                                       ($_ (println! $lastmessage))
                                       ;; SOUL INPUT INTERCEPT
                                       ;; Layer 1: Native pre-computation (no LLM cost)
                                       ($soul_precompute (soul-pre-compute $msg))

                                       ;; Channel A: User Flourishing Signal (150 tokens)
                                       ($person_state (useGPT (LLM) 150 (reasoningMode)
                                         (soul-flourishing-prompt $msg)))
                                       ($_ (change-state! &person_state $person_state))
                                       ($_ (println! (PERSON_STATE: $person_state)))

                                       ;; Channel B+C: Task Integrity + Soul Alignment (500 tokens)
                                       ($soul_context_in (soul-brief-symbolic))
                                       ($soul_verdict_in (useGPT (LLM) 500 (reasoningMode)
                                         (soul-eval-prompt $soul_context_in $msg $person_state)))
                                       ($_ (change-state! &soul_verdict_in $soul_verdict_in))
                                       ($_ (println! (SOUL_VERDICT_IN: $soul_verdict_in)))

                                       ;; Layer 3: Calibration recording
                                       ($_ (soul-calibration-record $soul_precompute $soul_verdict_in $msg))

                                       ;; Soul note on non-PROCEED; reset D-lite flag
                                       ($_ (if (not (soul-proceed? $soul_verdict_in))
                                               (soul-note-record $soul_verdict_in "input" $msg) _))
                                       ($_ (change-state! &soul_ack_sent False))

                                       ;; $send assembly for FLAG and PROCEED
                                       ($send (py-str ($prompt
                                                       " SOUL_CONTEXT: " $soul_context_in
                                                       " SOUL_VERDICT: " $soul_verdict_in
                                                       " PERSON_STATE: " $person_state
                                                       " SOUL-NOTE: " (soul-extract-flag-note $soul_verdict_in)
                                                       $lastmessage)))
                                       ($_ (println! (CHARS_SENT: (string_length $send) $send)))
                                       ($respi (if (== (provider) OpenAI)
                                                   (useGPT (LLM) (maxOutputToken) (reasoningMode) $send)
                                                   (py-call (lib_llm_asicloud.useMiniMax $send))))
                                       ($resp (py-call (helper.balance_parentheses $respi)))
                                       ($response (if (== "(" (first_char $resp)) $resp (progn (println! $resp) (repr (REMEMBER:OUTPUT_NOTHING_ELSE_THAN: ((skill arg) ...))))))
                                       ($sexpr (catch (sread $response)))
                                       ($_ (change-state! &error ()))
                                       ($_ (HandleError MULTI_COMMAND_FAILURE_NOTHING_WAS_DONE_PLEASE_CORRECT_PARENTHESES_AND_USE_QUOTES_AND_RETRY $response $sexpr))
                                       ($_ (println! (RESPONSE: $sexpr)))

                                       ;; SOUL OUTPUT INTERCEPT
                                       ;; metta() gate: detect soul namespace mutation (native, no LLM cost)
                                       ($metta_cmds (collapse (superpose $sexpr)))
                                       ($soul_mutation_flag
                                         (if (soul-any-metta? $metta_cmds)
                                             (let $args (collapse (let $c (superpose $metta_cmds)
                                                           (if (soul-is-metta-cmd? $c)
                                                               (soul-extract-metta-arg $c) ())))
                                                  (if (any (collapse (let $a (superpose $args)
                                                              (soul-metta-targets-soul-namespace? $a))))
                                                      (if (soul-mutation-pending?)
                                                          "SOUL-NAMESPACE-MUTATION-CONFLICT"
                                                          (progn
                                                            (change-state! &soul_mutation_lock
                                                              (py-str ("LOCKED: " (car-atom $args))))
                                                            "SOUL-NAMESPACE-MUTATION-PENDING"))
                                                      ""))
                                             ""))

                                       ;; Output soul evaluation (500 tokens)
                                       ($soul_context_out (soul-brief-symbolic))
                                       ($soul_verdict_out (useGPT (LLM) 500 (reasoningMode)
                                         (soul-eval-prompt $soul_context_out
                                           (py-str ((repr $sexpr) " " $soul_mutation_flag))
                                           $person_state)))
                                       ($_ (change-state! &soul_verdict_out $soul_verdict_out))
                                       ($_ (println! (SOUL_VERDICT_OUT: $soul_verdict_out)))

                                       ;; Soul note on non-PROCEED output
                                       ($_ (if (not (soul-proceed? $soul_verdict_out))
                                               (soul-note-record $soul_verdict_out "output" (repr $sexpr)) _))

                                       ($results (RESULTS: (collapse (let $s (superpose $sexpr) (COMMAND_RETURN: ($s (HandleError SINGLE_COMMAND_FORMAT_ERROR_NOTHING_WAS_DONE_PLEASE_FIX_AND_RETRY $s (catch (eval $s)))))))))
                                       ($_ (println! $results)))
                                      (progn (if (or $msgnew  (not (== $sexpr ()))) (addToHistory $msg $response $sexpr $msgnew) _)
                                             (change-state! &lastresults (string-safe (repr $results))))) _))
                      (sleep (sleepInterval))
                      (mettaclaw (+ 1 $k))))))
