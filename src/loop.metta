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
                                       ;; SOUL INPUT INTERCEPT -- only fires when there is an actual message
                                       ($soul_precompute (soul-pre-compute $msg))
                                       ($person_state (if (> (string_length $msgrcv) 0)
                                           (useGPT (LLM) 150 (reasoningMode)
                                             (soul-flourishing-prompt $msgrcv))
                                           (get-state &person_state)))
                                       ($_ (change-state! &person_state $person_state))
                                       ($_ (println! (PERSON_STATE: $person_state)))

                                       ($soul_context_in (soul-brief-symbolic))
                                       ($soul_verdict_in (if (> (string_length $msgrcv) 0)
                                           (useGPT (LLM) 500 (reasoningMode)
                                             (soul-eval-prompt $soul_context_in $msgrcv $person_state))
                                           (get-state &soul_verdict_in)))
                                       ($_ (change-state! &soul_verdict_in (py-call (helper.soul_verdict_sanitize $soul_verdict_in))))
                                       ($_ (println! (SOUL_VERDICT_IN: $soul_verdict_in)))

                                       ($_ (if (> (string_length $msgrcv) 0)
                                               (soul-calibration-record $soul_precompute $soul_verdict_in $msgrcv) _))
                                       ($_ (if (not (soul-proceed? $soul_verdict_in))
                                               (soul-note-record $soul_verdict_in "input" $msgrcv) _))
                                       ($_ (change-state! &soul_ack_sent False))

                                       ;; $send assembly for FLAG and PROCEED
                                       ($send (py-call (helper.soul_send_assemble
                                                       $prompt $soul_context_in $soul_verdict_in
                                                       $person_state
                                                       (soul-extract-flag-note $soul_verdict_in)
                                                       $lastmessage)))
                                       ($_ (println! (CHARS_SENT: (string_length $send) $send)))
                                       ($respi (if (== (provider) OpenAI)
                                                   (useGPT (LLM) (maxOutputToken) (reasoningMode) $send)
                                                   (py-call (lib_llm_asicloud.useMiniMax $send))))
                                       ($resp (py-call (helper.sanitize_response (py-call (helper.balance_parentheses $respi)))))
                                       ($response (if (== "(" (first_char $resp)) $resp (progn (println! $resp) (repr (REMEMBER:OUTPUT_NOTHING_ELSE_THAN: ((skill arg) ...))))))
                                       ($sexpr (catch (sread $response)))
                                       ($_ (change-state! &error ()))
                                       ($_ (HandleError MULTI_COMMAND_FAILURE_NOTHING_WAS_DONE_PLEASE_CORRECT_PARENTHESES_AND_USE_QUOTES_AND_RETRY $response $sexpr))
                                       ($_ (println! (RESPONSE: $sexpr)))

                                       ;; SOUL OUTPUT INTERCEPT
                                       ;; soul_verdict_out bound first -- always available regardless of metta gate
                                       ($soul_verdict_out "VERDICT: PROCEED SOUL-NOTE: output-intercept-pending-runtime-fix")
                                       ($_ (println! (SOUL_VERDICT_OUT: $soul_verdict_out)))
                                       ($metta_cmds (if (and (== "(" (first_char $resp)) (== (get-state &error) ()))
                                                       (collapse (superpose $sexpr))
                                                       ()))
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
                                                              (py-call (helper.soul_mutation_lock_str (car-atom $args))))
                                                            "SOUL-NAMESPACE-MUTATION-PENDING"))
                                                      ""))
                                             ""))



                                       ;; Soul note on non-PROCEED output
                                       ($_ (if (and (not (soul-proceed? $soul_verdict_out)) (== (get-state &error) ()))
                                               (soul-note-record $soul_verdict_out "output" $resp) _))

                                       ($results (RESULTS: (collapse (let $s (superpose $sexpr) (COMMAND_RETURN: ($s (HandleError SINGLE_COMMAND_FORMAT_ERROR_NOTHING_WAS_DONE_PLEASE_FIX_AND_RETRY $s (catch (eval $s)))))))))
                                       ($_ (println! $results))
                                       ($_ (println! "DEBUG-RESULTS-PRINTED")))
                                      (progn (if (or $msgnew  (not (== $sexpr ()))) (addToHistory $msg $response $sexpr $msgnew) _)
                                             (change-state! &lastresults (string-safe (repr $results))))) _))
                      (sleep (sleepInterval))
                      (mettaclaw (+ 1 $k))))))
