;; soul/test_c2_seed.metta
;; C2: Execute !(initSoulSeeds) — seeds 40 compass-depth entries into ChromaDB.
;; Requires full runtime chain: lib_llm (useGPTEmbedding), lib_chromadb,
;; helper.py (file_exists/touch_file), utils (string-safe, get_time_as_string),
;; memory (remember).
;;
;; Run: docker exec clarityclaw_agent sh /app/PeTTa/run.sh \
;;        /app/PeTTa/repos/mettaclaw/soul/test_c2_seed.metta default
;;
;; Expected: prints "Seeding soul memory -- compass depth",
;;           40 remember calls execute against ChromaDB with OpenAI embeddings,
;;           soul_seeded.flag created.

!(import! &self (library lib_llm))
!(import! &self (library petta_lib_chromadb lib_chromadb))
!(import! &self (library mettaclaw ./src/helper.py))
!(import! &self (library mettaclaw ./src/utils))
!(import! &self (library mettaclaw ./src/memory))
!(import! &self (library mettaclaw ./soul/soul_kernel))
!(import! &self (library mettaclaw ./soul/soul_memory))
!(initSoulSeeds)
