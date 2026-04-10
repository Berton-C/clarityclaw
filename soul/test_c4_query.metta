;; soul/test_c4_query.metta
;; C4: Retrieval proof -- query ChromaDB for a seeded soul pattern.
;; Run after C2 has seeded successfully.
;;
;; Run: docker exec clarityclaw_agent sh /app/PeTTa/run.sh /app/PeTTa/repos/mettaclaw/soul/test_c4_query.metta default
;;
;; Expected: returns text containing AgencyBalance CAPTURED-DISGUISED content.

!(import! &self (library lib_llm))
!(import! &self (library petta_lib_chromadb lib_chromadb))
!(import! &self (library mettaclaw ./src/utils))
!(import! &self (library mettaclaw ./src/memory))
!(query "AgencyBalance CAPTURED-DISGUISED")
