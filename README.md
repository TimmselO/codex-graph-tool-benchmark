# Graft vs CodeGraph vs Baseline: a Codex Benchmark

A small case study comparing token use, cached and uncached input, output, runtime, MCP calls, and run validity across four tracing and implementation tasks.

**Graft used 20.95% fewer total tokens and 11.10% less uncached input than baseline, with 1.95% longer runtime. CodeGraph was faster on tracing tasks but used more tokens on the implementation tasks.** These results do not establish a correctness winner or a measured subscription-allowance saving.

## Results at a glance

Main cohort: **36 variant-runs**, with three repetitions per task per variant. The three variants from task3 run1 are retained separately because they performed the wrong task.

| Metric | Baseline | Graft | CodeGraph |
|---|---:|---:|---:|
| Input tokens | 25,884,146 | 20,435,358 | 29,913,115 |
| Cached input | 24,617,600 | 19,309,440 | 28,546,048 |
| Uncached input | 1,266,546 | 1,125,918 | 1,367,067 |
| Output tokens | 147,009 | 143,654 | 143,227 |
| Total tokens | 26,031,155 | 20,579,012 | 30,056,342 |
| Mean runtime (seconds) | 216.14 | 220.36 | 223.53 |
| MCP calls | 0 | 178 | 92 |

Cached input is already included in input: **uncached = input − cached; total = input + output**. These are cumulative agent-usage figures, not unique source content or peak context sizes.

[Read the full report](docs/report.md) · [Methodology](docs/methodology.md) · [Validation](docs/validation.md) · [Publication redactions](docs/publication.md)

## Workload

The October 2026 case study used one private TypeScript/React/Node application, with approximately 291 files reported by its structural index. The available scripts specify **GPT-5.6 Sol, high reasoning effort**.

| Task | Description | Mode |
|---|---|---|
| 1 | Trace a station action into a VDA 5050 order | Read-only |
| 2 | Trace map export through the runtime | Read-only |
| 3 | Change layout-inspector dismissal behavior and test it | Implementation |
| 4 | Add native project import/export for transfer between instances | Implementation |

Application names, personal paths, private repository identifiers and detailed implementation logs have been removed or generalized. The numerical measurements and MCP call lists are preserved. See [task descriptions](tasks/README.md).

## Recalculate the published results

Python 3.10+ is sufficient; no third-party Python packages are required.

```bash
python3 scripts/analyze.py --check
python3 -m unittest discover -s tests -v
```

To regenerate the statistics:

```bash
python3 scripts/analyze.py
```

The analysis validates all 39 metric rows against the 13 sanitized text summaries and computes sums, means, medians, ranges, sample standard deviations and aggregate cache shares. Command-call counts come from the private JSONL audit and cannot be reconstructed from the published text summaries.

## Run your own experiment

The [historical harness snapshots](scripts/historical/) show the setup used by the available scripts. They are adapted for publication, require an explicit disposable-directory marker, and are not guaranteed to match every historical run exactly. They are not a hardened sandbox or a general benchmark framework.

For implementation tasks, these scripts **reset tracked files and delete untracked/ignored files** in the three benchmark checkouts. Use only disposable copies with dependencies prepared. Read the [setup instructions](docs/methodology.md#running-the-harness) first. Do not run them against a working project checkout containing valuable changes or data.

The private application source is not included. You can reproduce the calculations from the public dataset, but you cannot fully reproduce the original agent workload from this repository alone. Replace the sanitized task prompts with appropriate tasks for your own codebase.

## What this experiment does and does not show

- Graft has the lowest mean total-token usage on all four tasks in this dataset.
- CodeGraph offers faster tracing in this dataset; fewer MCP calls do not consistently mean fewer tokens.
- Task4 accounts for 52.22% of baseline total tokens and heavily influences aggregate results.
- Browser tests were blocked by sandbox listener restrictions. Full test suites had failures and implementations differed in scope and behavior.
- The experiment used fixed variant order and only three retained repetitions per task. There is no common correctness rubric or statistical significance claim.
- Graft reported structural indexing without an available deep semantic manifest. This is not a comparison against fully enriched Graft indexing.
- Token savings do **not** establish an identical reduction in subscription allowance. Consult [official OpenAI usage guidance](https://learn.chatgpt.com/docs/pricing) and measure allowance consumed per correctly completed task.

## Files

- `data/run-metrics.csv`: all 39 runs, including the excluded triplet.
- `data/per-task-statistics.csv` and `data/statistics.json`: calculated statistics.
- `data/results/`: 13 sanitized text summaries.
- `docs/`: report, methodology, validation and publication notes.
- `scripts/`: analysis, guard preparation and historical harness snapshots.
- `tests/`: dataset validation and exclusion-boundary checks.

This is a case study, not an official evaluation or endorsement by OpenAI, Graft or CodeGraph.
