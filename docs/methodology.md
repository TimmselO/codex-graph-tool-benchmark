# Methodology and reproducibility

## Recorded experiment

Thirteen text summaries cover four tasks and three variants. Tasks1, 2 and 4 each have three repetitions. Task3 has four repetitions, with run1 excluded because its private agent answers performed the map-export trace instead of the requested inspector implementation.

The main cohort therefore contains 12 variant-runs per variant, 36 total. The all-runs cohort contains 39. The excluded triplet is never reassigned to task2.

Available scripts specify GPT-5.6 Sol and high reasoning effort, ephemeral execution and ignored user configuration. Baseline uses ordinary source navigation and is instructed not to use Graft or CodeGraph. Each graph variant is instructed to use its MCP server and call its main exploration tool at least once; context-tool CLI use is rejected by the harness.

Tasks1/2 use read-only execution and `GRAFT_NO_REFRESH=1` for Graft. Their available scripts do not reset the source between variants. Tasks3/4 use workspace-write execution, reset each checkout to a shared base revision, remove generated artifacts while preserving dependency/index directories, and prepare the relevant graph before starting the timer. The shared private base commit has been replaced by a label in the published summaries. Tasks1/2 summaries lack equivalent starting-commit metadata.

The timer surrounds the Codex process. Preparation, source reset, index build/sync and saved-implementation capture are outside the reported runtime. All variants run in fixed baseline → Graft → CodeGraph order. Persistent indexes and prompt caching mean this is not a controlled cold-cache experiment.

Graft's recorded structural graph had 1,541 nodes, 6,181 edges and 291 file cards in implementation summaries. Agent reports indicated no available deep semantic manifest. Historical Codex, Graft, CodeGraph, OS and dependency versions were not preserved in the supplied summaries; current installed versions must not be presented as historical versions.

## Measurements and statistics

- Input includes cached input; `uncached = input - cached`.
- Total is `input + output`; cached input is not added again.
- Output uses the reported output-token count, not the length of the visible final answer.
- Cache share is `sum(cached) / sum(input)`, rather than an unweighted mean of percentages.
- MCP calls count completed call records, not individual result chunks.
- Command-call counts were extracted from private JSONL traces. They are preserved in the metric dataset but cannot be verified from the public text summaries alone.
- Sample standard deviation uses `n - 1`; single-run excluded statistics use `null`.
- Percentage comparisons use cohort sums (equivalently means when repetition counts match). Equal-task comparisons average the four task-level ratios.

The analysis script validates metric identities, token arithmetic, expected repetitions/cohorts, source-summary measurements and MCP counts. It then reproduces the checked-in JSON and statistics CSV. This validates the dataset and calculations, not the application implementations.

## Running the harness

Requirements: Bash, Git, GNU time at `/usr/bin/time`, jq, tar, Codex CLI, Graft CLI and CodeGraph CLI. Prepare three disposable checkouts named `baseline`, `graft` and `codegraph` at the same revision, outside this publication repository. Install the project's dependencies in each checkout and initialize structural indexes for the graph variants.

The following template intentionally does not clone a private repository or choose a source revision:

```bash
export BENCH_ROOT=/absolute/path/to/disposable-benchmark
mkdir -p "$BENCH_ROOT"

# Prepare baseline/, graft/ and codegraph/ as disposable checkouts first.
# Verify that these paths contain no valuable edits or user data.
touch "$BENCH_ROOT/.disposable-benchmark"

git -C "$BENCH_ROOT/baseline" rev-parse HEAD > "$BENCH_ROOT/base-commit"
bash scripts/prepare-guards.sh

# Review the task and available CLI flags before running.
bash scripts/historical/task1.sh
```

For task3/task4, reset and clean operations discard changes inside all three variant checkouts. The marker is an acknowledgement, not an isolation mechanism. For task1/task2, manually verify equal clean source state; the historical read-only scripts do not reset it.

The generated guards block the competing context-tool CLI in graph variants and both context-tool CLIs in baseline. Each graph variant's own CLI is constrained by the prompt and post-run log check, not by its guard. Absolute executable paths or other indirect access could bypass a PATH guard. The historical regex is an audit heuristic, not a security boundary.

The harness records private JSONL, stderr, timing and, for implementation tasks, patches and new-file archives under `$BENCH_ROOT/results`. Do not publish that directory automatically. Extract and inspect a sanitized public dataset separately.

The scripts have been checked for shell syntax and their guard behavior tested locally. New live Codex benchmark runs were not executed during publication, and compatibility with other tool versions is not established. If the original model is unavailable, choose another model explicitly and keep the new results separate from this dataset.

## Improvements for another experiment

1. Randomize or balance variant order and increase repetition count.
2. Record exact submitted prompts, source/dependency/tool versions and starting-state checks for every task.
3. Separate warm- and cold-cache conditions and measure index preparation separately.
4. Use identical acceptance tests, with browser/server execution available.
5. Score tracing answers for accuracy and completeness; score implementations for required behavior and regressions.
6. Compare resource use per correctly completed task, including subscription-allowance changes when relevant.
