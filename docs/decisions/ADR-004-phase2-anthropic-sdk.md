# ADR-004: Phase 2 Anthropic SDK Migration via LiteLLM

**Date:** March 2026
**Status:** Planned -- not yet active
**Deciders:** Berton Bennett (ClarityDAO)

## Decision

Use LiteLLM proxy to route soul evaluation calls (Channel B+C) through Claude
(Anthropic) while maintaining OpenAI for embeddings (text-embedding-3-large).

## Context

Phase 1 uses OpenAI gpt-5.4 for all LLM calls. The soul architecture makes up to
four useGPT() calls per cycle. For Phase 2, Channel B+C soul evaluation
(500-token semantic evaluation against soul criteria) is the candidate for
Claude, which may produce more reliable soul-aligned verdicts.

OpenAI embeddings (text-embedding-3-large) remain hardcoded in Patrick's
lib_llm.metta via useGPTEmbedding(). This cannot be routed through LiteLLM
without modifying lib_llm.metta. Embeddings stay on OpenAI in Phase 2.

The litellm_config.yaml already exists in the repo. Activation requires:
1. Adding LiteLLM service to docker-compose.yml
2. Setting OPENAI_BASE_URL=http://litellm:4000 in .env
3. Adding ANTHROPIC_API_KEY to .env

## Consequences

Phase 1 is entirely OpenAI. Phase 2 adds Claude for soul evaluation only.
Embeddings remain on OpenAI permanently until lib_llm.metta is modified upstream.
