# ADR-003: Communication Channel -- IRC for Phase 1

**Date:** March 2026
**Status:** Decided
**Deciders:** Berton Bennett (ClarityDAO)

## Decision

Use Libera.Chat IRC (##clarityclaw) as the ClarityClaw communication channel for Phase 1.

## Context

Mattermost (self-hosted Docker, Team Edition) was built and wired but parked due to
setup complexity during initial MeTTaClaw bring-up. IRC is operational and
sufficient for Phase 1 soul architecture implementation and testing. Remote team
members can access the IRC channel directly.

Patrick's codebase already supports channel-agnostic operation via the COMMCHANNEL
environment variable (values: irc or mattermost). The soul architecture intercepts
at the loop level, before channel-specific code runs -- it works identically on
either channel.

## Consequences

Phase 1 soul implementation and testing proceeds on IRC.

Mattermost can be reactivated by setting COMMCHANNEL=mattermost in .env and
completing the Mattermost bot account setup (documented in SETUP.md). No soul
architecture changes are required to make that switch.

When to revisit: when persistent message history, private channels, or structured
bot account management become operationally necessary.
