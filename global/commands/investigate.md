Systematic debugging. Iron Law: no fixes without root cause.

$ARGUMENTS describes the bug or symptom to investigate.

## Phase 1: Collect evidence

Gather before theorizing:

- Read error messages, logs, stack traces
- Reproduce the issue (run the failing command/test)
- Check git log for recent changes in the affected area
- Read the relevant source code

Document findings as you go:
```
Symptom: {what's broken}
Repro: {how to trigger}
Scope: {what's affected, what works fine}
Recent changes: {relevant commits}
```

## Phase 2: Analyze patterns

Match against common root causes:

| Pattern | Signals |
|---------|---------|
| Race condition | Intermittent, timing-dependent, works in debugger |
| Nil/null propagation | Crash in unrelated code, optional chaining gaps |
| State corruption | Works first time, fails on retry, stale data |
| Integration failure | Works in isolation, fails with real dependencies |
| Config drift | Works locally, fails in CI/staging/prod |
| Stale cache | Works after clean build, fails incrementally |

## Phase 3: Hypothesize and test

Form one hypothesis at a time. Test it:

1. State the hypothesis clearly
2. Predict what you'd see if it's correct
3. Run a test that distinguishes this hypothesis from alternatives
4. If confirmed → Phase 4. If refuted → next hypothesis.

**3-strike rule:** If three hypotheses fail, step back and re-examine assumptions from Phase 1. You may be looking at the wrong layer.

## Phase 4: Fix

Only after root cause is confirmed:

- Fix the root cause, not the symptom
- Write a regression test that fails without the fix
- Run the full test suite
- If fix touches > 5 files, pause and reassess — the blast radius may indicate a deeper issue

## Phase 5: Verify and report

```
## Debug Report

**Symptom:** {description}
**Root cause:** {what was actually wrong}
**Fix:** {what was changed and why}
**Regression test:** {test name/path}
**Status:** FIXED / FIXED_WITH_CONCERNS / BLOCKED

{if BLOCKED: what's needed to unblock}
{if FIXED_WITH_CONCERNS: what to watch for}
```

## Notes

- Resist the urge to fix things along the way — note them but stay focused
- If the investigation reveals the problem is elsewhere (wrong layer, wrong repo), say so early
- $ARGUMENTS can include file paths, error messages, or ticket references to focus the search
