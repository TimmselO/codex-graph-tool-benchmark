# Validation record

This is a sanitized summary of the private logs inspected during analysis. It records evidence and agent reports; it is not a new execution of the implementations. No application source, endpoints, private commit identifiers or code excerpts are published.

## Harness checks

All 39 variant-runs contained one completed turn. All listed MCP calls reported completed; baseline used no MCP calls. No context-tool CLI invocation matched the historical harness check. Input, cached input, output and MCP counts matched the original text summaries.

The main cohort contains 36 variant-runs. The three task3 run1 variants completed the wrong task and are excluded. A completed process and successful MCP calls do not establish functional correctness.

## Implementation checks

| Task | Run | Variant | Static checks | Focused tests | Browser acceptance |
|---|---:|---|---|---|---|
| 3 | 2 | baseline | Typecheck, lint and build reported passed | 19 passed | Blocked: sandbox listener denial |
| 3 | 2 | graft | Typecheck and lint reported passed | 12 passed | Blocked: sandbox listener denial |
| 3 | 2 | codegraph | Typecheck, lint and build reported passed | Not separately reported | Blocked: sandbox listener denial |
| 3 | 3 | baseline | Typecheck, lint and build reported passed | Not separately reported | Blocked: sandbox listener denial |
| 3 | 3 | graft | Typecheck, lint and build reported passed | 12 passed | Blocked: sandbox listener denial |
| 3 | 3 | codegraph | Typecheck, lint and build reported passed | Not separately reported | Blocked: sandbox listener denial |
| 3 | 4 | baseline | Typecheck, lint and build reported passed | 17 passed | Blocked: sandbox listener denial |
| 3 | 4 | graft | Typecheck, lint and build reported passed | 39 passed | Blocked: sandbox listener denial |
| 3 | 4 | codegraph | Typecheck, lint and build reported passed | Not separately reported | Blocked: sandbox listener denial |
| 4 | 1 | baseline | Typecheck, lint and build reported passed | 19 passed | Blocked: sandbox listener denial |
| 4 | 1 | graft | Typecheck, lint and build reported passed | 19 passed | Blocked: sandbox listener denial |
| 4 | 1 | codegraph | Typecheck, lint and build reported passed | 17 passed | Blocked: sandbox listener denial |
| 4 | 2 | baseline | Typecheck, lint and build reported passed | 18 passed | Blocked: sandbox listener denial |
| 4 | 2 | graft | Typecheck, lint and build reported passed | 19 passed | Blocked: sandbox listener denial |
| 4 | 2 | codegraph | Typecheck, lint and build reported passed | 14 passed | Blocked: sandbox listener denial |
| 4 | 3 | baseline | Typecheck, lint and build reported passed | 21 passed | Blocked: sandbox listener denial |
| 4 | 3 | graft | Typecheck, lint and build reported passed | Reported passed; count omitted | Blocked: sandbox listener denial |
| 4 | 3 | codegraph | Typecheck, lint and build reported passed | 19 passed | Blocked: sandbox listener denial |

All implementation runs reported full-suite failures. Most were attributed to sandbox network/socket/interface restrictions, but some also involved simulator timer/client errors. Their causes were not independently isolated. The implementations differed in scope and behavior and were not evaluated against one common acceptance rubric.

Tracing-task answers were not independently scored for accuracy or completeness. The excluded task3 run1 triplet explicitly reported no edits or tests.
