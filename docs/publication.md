# Publication notes

## Included

The public dataset retains numerical measurements, repetition identifiers, task/variant labels, MCP tool names and completed statuses. All 13 text summaries are included after sanitization. The main report retains the failed/wrong-task triplet separately, incomplete functional validation and other methodological limitations.

## Removed or generalized

- Personal usernames, hostnames and absolute home-directory paths.
- The private source commit identifier, source commit description, branch names and pull-request references.
- Application branding in task prompts.
- Detailed application architecture, endpoint descriptions, source snippets, patches and agent answers.
- Private JSONL traces, stderr logs, saved implementation archives and the original evidence ZIP.

Sanitized text summaries are labeled as such. They are not byte-identical originals. The numerical fields and MCP call lists are unchanged, and can be checked against `data/run-metrics.csv` by running `scripts/analyze.py --check`.

The validation document is a deliberately concise record of observed checks and reported outcomes. It does not provide enough application detail to independently verify implementation correctness. The excluded run's wrong-task classification depends on the private trace review, not just its public summary label.

The historical shell scripts are snapshots of the available local harness, with application names generalized, the benchmark root made explicit, model/effort overrides enabled and a disposable-root marker added. These adaptations did not generate the historical measurements. They must not be presented as exact historical execution artifacts.

The source application remains unpublished. This repository supports independent recalculation and methodological inspection, while full workload reproduction requires a separate codebase and task adaptation.

No application source, credentials or private diagnostic archive should be added to this repository through a blanket upload of the original analysis folder. Future experiment logs need a new content review before publication.
