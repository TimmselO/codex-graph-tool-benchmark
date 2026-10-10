# Codex benchmark summary: Baseline, Graft and CodeGraph

Analysis date: 10 October 2026. Available benchmark scripts specify `gpt-5.6-sol` with high reasoning effort.

## Main result

**Graft reduced aggregate total tokens by 20.95% and uncached input by 11.10%, while taking 1.95% longer than baseline. CodeGraph was faster on the two tracing tasks, but increased aggregate total tokens by 15.46% and runtime by 3.42%.** The evidence does not establish a correctness winner.

## Scope and calculation

- Analyzed 13 result text files containing 39 variant-runs.
- Main comparison: 36 harness-valid variant-runs, with three repetitions per task and variant. Task3 uses runs 2–4; its run1 is excluded.
- All 13 original text summaries were analyzed. All 39 token summaries and MCP counts matched companion private JSONL logs. The published text summaries are sanitized; the private logs and application source are omitted.
- Cached tokens are included in input. Uncached input = input − cached; total tokens = input + output. Cache share uses aggregate cached/input.
- Token figures are cumulative agent usage, not unique repository content or maximum context length.

## Aggregate results, excluding task3 run1

| Metric | Baseline | Graft | CodeGraph |
|---|---:|---:|---:|
| Input tokens | 25,884,146 | 20,435,358 | 29,913,115 |
| Cached input | 24,617,600 | 19,309,440 | 28,546,048 |
| Uncached input | 1,266,546 | 1,125,918 | 1,367,067 |
| Output tokens | 147,009 | 143,654 | 143,227 |
| Total tokens | 26,031,155 | 20,579,012 | 30,056,342 |
| Runtime, summed (seconds) | 2,593.64 | 2,644.34 | 2,682.41 |
| MCP calls | 0 | 178 | 92 |
| Runtime, mean/run (seconds) | 216.14 | 220.36 | 223.53 |
| Input cache share | 95.11% | 94.49% | 95.43% |

Graft used fewer total tokens than baseline in 8/12 comparisons; CodeGraph did so in 6/12. Both were faster in 6/12. Fewer MCP calls did not consistently mean lower token use.

## Per-task results

Means across three repetitions. M = million tokens; k = thousand tokens.

| Task | Variant | Input M | Cached M | Uncached k | Output k | Total M | Seconds | MCP calls |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | Baseline | 1.158 | 1.062 | 96.05 | 5.43 | 1.164 | 100.74 | 0.00 |
| 1 | Graft | 0.833 | 0.767 | 66.31 | 6.31 | 0.840 | 124.50 | 17.00 |
| 1 | CodeGraph | 0.945 | 0.863 | 82.32 | 4.76 | 0.950 | 87.45 | 10.33 |
| 2 | Baseline | 0.890 | 0.796 | 93.90 | 6.08 | 0.896 | 132.45 | 0.00 |
| 2 | Graft | 0.859 | 0.785 | 73.32 | 6.70 | 0.865 | 119.66 | 22.67 |
| 2 | CodeGraph | 0.898 | 0.811 | 87.36 | 4.48 | 0.903 | 86.76 | 8.33 |
| 3 | Baseline | 2.073 | 1.976 | 96.78 | 12.86 | 2.086 | 261.18 | 0.00 |
| 3 | Graft | 1.844 | 1.752 | 91.67 | 12.62 | 1.857 | 252.69 | 6.00 |
| 3 | CodeGraph | 3.037 | 2.898 | 139.13 | 13.04 | 3.050 | 269.78 | 6.00 |
| 4 | Baseline | 4.506 | 4.371 | 135.45 | 24.63 | 4.531 | 370.18 | 0.00 |
| 4 | Graft | 3.276 | 3.132 | 144.01 | 22.26 | 3.298 | 384.59 | 13.67 |
| 4 | CodeGraph | 5.091 | 4.944 | 146.89 | 25.46 | 5.117 | 450.14 | 6.00 |

- **Task1 — station action → VDA 5050 order:** Graft reduced total tokens by 27.87% but took 23.59% longer. CodeGraph reduced total tokens by 18.40% and runtime by 13.19%.
- **Task2 — map-export runtime trace:** Graft reduced total tokens by 3.46% and uncached input by 21.92%. CodeGraph used 0.71% more total tokens but finished 34.50% faster.
- **Task3 — inspector dismissal change:** Graft reduced total tokens by 11.00% and runtime by 3.25%. CodeGraph increased total tokens by 46.20% and runtime by 3.29%.
- **Task4 — native project transfer:** Graft reduced total tokens by 27.21%, but uncached input rose 6.32% and runtime rose 3.89%. CodeGraph increased total tokens by 12.93% and runtime by 21.60%.

Task4 represents 52.22% of baseline total tokens. Giving each task equal weight produces average task-level total-token changes of −17.38% for Graft and +10.36% for CodeGraph.

## Excluded task3 run1

Although its text file prints `SUCCESS`, the raw answers trace map export and explicitly report no edits or tests. The recorded activity matches task2 rather than the requested task3 inspector change. Exclude all three variants from the main comparison; this is evidence of the wrong task being performed, not an MCP/process failure.

| Variant | Input | Cached | Uncached | Output | Total | Seconds | MCP calls |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline | 1,131,373 | 1,046,400 | 84,973 | 5,337 | 1,136,710 | 147.34 | 0 |
| Graft | 845,636 | 754,816 | 90,820 | 6,057 | 851,693 | 146.62 | 31 |
| CodeGraph | 645,720 | 597,632 | 48,088 | 3,707 | 649,427 | 82.92 | 5 |

Including all 13 files would give total-token sums of 27,167,865 baseline, 21,430,705 Graft and 30,705,769 CodeGraph. These are bookkeeping totals, not the primary comparison.

## Validity and limitations

- All 39 records have a completed turn; all listed MCP calls report completed. Baseline records no MCP calls.
- Harness validity does not prove task correctness. Task3/task4 logs report passing static checks and selected focused tests, but browser tests were blocked by sandbox loopback-listener restrictions and full suites had failures. Some failures also involved simulator timer/client errors whose causes were not independently isolated.
- Implementations differ in scope and behavior, including selection handling and transfer limits. No common acceptance rubric was applied. Tracing answers were not independently scored for correctness or completeness. Graft reported a structural index without an available deep semantic manifest, so these findings do not evaluate a fully enriched Graft index.
- The available scripts exclude preparatory index builds/synchronization from the Codex timer and always run baseline → Graft → CodeGraph. Cache, machine and service conditions can therefore be confounded with variant order.
- Only three repetitions per task were retained, with substantial variation: CodeGraph task4 ranged from 3.024M to 7.374M total tokens. Historical implementations and tests were inspected, not independently rerun.

## Recommendations

1. **Keep Graft as the provisional default for token reduction.** It has the lowest aggregate total and uncached input, with lower mean total tokens on every task.
2. **Use CodeGraph selectively for tracing when speed matters.** This dataset does not support replacing Graft with CodeGraph for all implementation work.
3. **Retain normal source navigation for straightforward edits.** Graph tooling did not consistently save time.
4. **Compare cached, uncached and output separately.** Total-token reductions do not establish identical reductions in charges or account allowance. Graft’s own “tokens saved” messages are not measured baseline comparisons.
5. **Improve the next benchmark:** randomize variant order; save exact prompts, source revisions and tool versions; separate warm/cold-cache conditions; record indexing time; and apply identical acceptance tests in an environment that permits browser execution.

## Supporting files

- [Individual run metrics](../data/run-metrics.csv)
- [Aggregate and per-task statistics, including medians and variation](../data/per-task-statistics.csv)
- [Sanitized validation record](validation.md)
- [Sanitized result texts](../data/results)
