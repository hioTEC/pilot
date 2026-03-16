# Agent Instructions

> This file is read by all AI agents working on this project.
> It defines boundaries, conventions, and quality expectations.

## Architecture boundaries

<!-- Describe the key layers and their allowed dependencies.
     Example: UI → Service → Repository → Database
     Agents should not create cross-layer shortcuts. -->

## Coding conventions

- Prefer simple, readable code over clever abstractions
- Derive state from data; don't store what can be computed
- Similar features should feel similar to use (UI, API, code patterns)
- Fix problems at the architecture level, not at the symptom level
- If no good solution exists, leave a TODO — don't paper over it

## Quality gates

Before completing any task, agents must ensure:
- [ ] `npx tsc --noEmit` passes (zero type errors)
- [ ] `npx eslint .` passes (zero lint errors)
- [ ] `npx vitest run` passes (all unit tests green)
- [ ] `npm run build` succeeds
- [ ] New UI changes have visual verification (screenshot or E2E)

## Git conventions

- One logical change per commit
- Commit messages: imperative mood, explain why not what
- Branch per task, PR per branch
- Co-author tag required: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

## What NOT to do

- Don't add defensive programming for internal code
- Don't create abstractions for one-time operations
- Don't add comments to code you didn't change
- Don't mock databases in integration tests
- Don't amend commits — create new ones
