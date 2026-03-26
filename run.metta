; run.metta -- ClarityClaw entry point
;
; IMPORTANT: No git-import! here.
; All source is baked into the image at build time from Berton-C/clarityclaw.
; This means runtime behavior is stable and fully under your control.
;
; To update from Patrick's repo:
;   1. Merge patham9/mettaclaw into Berton-C/clarityclaw on GitHub
;   2. docker compose build mettaclaw
;   3. docker compose up -d mettaclaw

!(import! &self (library lib_import))
!(import! &self (library petta_lib_chromadb lib_chromadb))
!(import! &self (library mettaclaw lib_mettaclaw))

!(mettaclaw)
