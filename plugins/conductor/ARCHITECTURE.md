# conductor — architecture & design record

Conductor is the successor to the deprecated `metis` plugin. It keeps metis's goal — make professional orchestration accessible and cost-efficient — but inverts the method, because the model underneath changed.

## Why a rewrite, not an edit

metis was engineered for 2024-era models: it routed work to the cheapest model that could do it, prescribed long step-by-step procedures, and asked agents to narrate their reasoning. Every one of those is now a tax. Strong current models follow brief direction better than long checklists, lose quality when over-instructed, and can fall back to a weaker model if asked to transcribe their reasoning. Conductor is a clean rewrite around how the model actually behaves now — no code, skills, or capabilities carried over.

## Operating philosophy (model-agnostic)

Conductor encodes the *Fable-era* operating style and runs it on whichever strong model is selected — Opus today, Fable or its successors when available. It never hard-depends on one model being present. The style: set direction and check results rather than steer every step; act when you have enough to act; prefer fewer, well-scoped units; verify against ground truth, not self-report.

## Layers — roles, not price tiers

metis's layers were defined by model price (an Opus spine, Sonnet/Haiku leaves). That assumption was baked into the structure, so it couldn't adapt. Conductor's layers are defined by *who holds the plan* and *where the context lives*:

| Layer | Role |
|---|---|
| **L0 — Entry** | Thin commands (`/conductor`, `/conductor:setup`). Load minimal context, route to the orchestrator. |
| **L1 — Orchestrator** | The selected strong model at high effort, holding the plan and the budget. Owns all judgment: frame, plan, decide, accept/reject. |
| **L2 — Isolated workers** | `Task` subagents in clean contexts (own worktree when parallel). Same model at low effort; cheap models only for a gated mechanical leaf. Return conclusions, not transcripts. |
| **Verifier** | A first-class role: fresh-context reviewers proving each unit against an oracle. Not something L1 does to itself. |

The same model can be L1 (high effort) and L2 (low effort). We tune the effort dial and the context boundary, not the brain.

## Cost model

Savings come from orchestration, not cheap brains:

- **Context isolation** — a worker's noise never enters the orchestrator's context (the 50–100× saving).
- **Plan before execute** — superpowers framing/planning prevents burning the model on a wrong approach.
- **Effort as the dial** — high for judgment, low for mechanical work.
- **Hard budgets** — per-run caps on worker dispatches and verify rounds.

We deliberately do **not** use Claude Code's dynamic-workflow runtime: in practice it can exhaust a subscription in a single run. Conductor reimplements its good ideas — isolation, adversarial verification, phased fan-out — bounded by an explicit budget on plain subagents.

## Superpowers is required

Conductor owns orchestration and delegates engineering discipline to the superpowers plugin (brainstorming, writing-plans, subagent-driven-development, TDD, code review, worktrees, verification-before-completion). It refuses to run without it rather than re-encoding a weaker copy.

## Scope — built in slices

- **Slice 1 (this release): the spine.** `/conductor` orchestrator + `/conductor:setup` + budget + memory. Interactive: you drive a goal, it plans → dispatches → verifies → reports under budget.
- **Slice 2: the flow.** triage → integrate (confidence-gated merge) → decision console. The autonomous / PR-pipeline layer.
- **Slice 3: project-awareness.** capabilities / profiles, kept only where they still earn their cost against a strong model.

## Relationship to metis

`metis` is deprecated and kept side-by-side for existing users. Conductor does not import metis's skills, capabilities, or profiles; it is a fresh design. There is no automatic migration in Slice 1.
