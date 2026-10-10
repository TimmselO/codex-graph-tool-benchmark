#!/usr/bin/env python3
"""Recalculate the published statistics using only the Python standard library."""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import statistics
from pathlib import Path

VARIANTS = ('baseline', 'graft', 'codegraph')
KEYS = ('input', 'cached', 'uncached', 'output', 'total', 'seconds', 'mcp_calls', 'command_calls')


def load_rows(path: Path) -> list[dict[str, object]]:
    """Validate the case-study schema and explicitly retained/excluded cohorts."""
    rows: list[dict[str, object]] = []
    seen: set[tuple[int, int, str]] = set()
    with path.open(newline='') as stream:
        reader = csv.DictReader(stream)
        required = {'task', 'run', 'variant', 'cohort', 'source', 'cache_pct', *KEYS}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError('Run metrics are missing required columns')
        for source in reader:
            row: dict[str, object] = dict(source)
            for key in ('task', 'run', *KEYS):
                if key == 'seconds':
                    row[key] = float(source[key])
                else:
                    row[key] = int(source[key])
            row['cache_pct'] = float(source['cache_pct'])
            task, run, variant = int(row['task']), int(row['run']), str(row['variant'])
            identity = (task, run, variant)
            if identity in seen:
                raise ValueError(f'Duplicate run: {identity}')
            seen.add(identity)
            if task not in (1, 2, 3, 4) or variant not in VARIANTS:
                raise ValueError(f'Unknown task or variant: {identity}')
            if run not in (range(1, 5) if task == 3 else range(1, 4)):
                raise ValueError(f'Unexpected repetition: {identity}')
            expected = 'excluded_task3_run1' if (task, run) == (3, 1) else 'harness_valid'
            if row['cohort'] != expected:
                raise ValueError(f'Unexpected cohort: {identity}')
            for key in KEYS:
                value = row[key]
                if not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                    raise ValueError(f'Invalid numeric field {key}: {identity}')
            if row['input'] <= 0 or row['cached'] > row['input']:
                raise ValueError(f'Invalid input/cache relationship: {identity}')
            if row['uncached'] != row['input'] - row['cached']:
                raise ValueError(f'Incorrect uncached input: {identity}')
            if row['total'] != row['input'] + row['output']:
                raise ValueError(f'Incorrect total: {identity}')
            if not math.isclose(row['cache_pct'], row['cached'] / row['input'] * 100):
                raise ValueError(f'Incorrect cache percentage: {identity}')
            if variant == 'baseline' and row['mcp_calls'] != 0:
                raise ValueError(f'Baseline used MCP: {identity}')
            if variant != 'baseline' and row['mcp_calls'] == 0:
                raise ValueError(f'Missing context-tool usage: {identity}')
            rows.append(row)
    if len(rows) != 39:
        raise ValueError(f'Expected 39 case-study rows, found {len(rows)}')
    return rows


def verify_sources(rows: list[dict[str, object]], directory: Path) -> None:
    """Cross-check published measurements against the sanitized text summaries."""
    for row in rows:
        name = str(row['source'])
        if Path(name).name != name:
            raise ValueError('Source must be a plain filename')
        text = (directory / name).read_text()
        blocks = dict(re.findall(
            r'Running:\s*(baseline|graft|codegraph)(.*?)(?=Running:\s*(?:baseline|graft|codegraph)|\Z)',
            text, re.S,
        ))
        body = blocks.get(str(row['variant']))
        if body is None:
            raise ValueError(f'Missing variant in {name}')
        match = re.search(r'\{\s*"input".*?\}', body, re.S)
        seconds = re.search(r'Seconds:\s*([\d.]+)', body)
        if match is None or seconds is None:
            raise ValueError(f'Missing measurements in {name}')
        metrics = json.loads(match.group())
        for key in ('input', 'cached', 'output', 'total'):
            if metrics[key] != row[key]:
                raise ValueError(f'Source mismatch: {name}, {row["variant"]}, {key}')
        if float(seconds.group(1)) != row['seconds']:
            raise ValueError(f'Runtime mismatch: {name}')
        calls = re.findall(r'^(graft|codegraph)\s+(\w+)\s+(\w+)\s*$', body, re.M)
        if len(calls) != row['mcp_calls'] or any(c[2] != 'completed' for c in calls):
            raise ValueError(f'MCP mismatch: {name}')


def summarize(rows: list[dict[str, object]]) -> dict[str, object]:
    values = {key: [row[key] for row in rows] for key in KEYS}
    return {
        'n': len(rows),
        'sum': {key: sum(items) for key, items in values.items()},
        'mean': {key: statistics.mean(items) for key, items in values.items()},
        'median': {key: statistics.median(items) for key, items in values.items()},
        'min': {key: min(items) for key, items in values.items()},
        'max': {key: max(items) for key, items in values.items()},
        'sample_sd': {key: statistics.stdev(items) if len(items) > 1 else None for key, items in values.items()},
        'cache_pct': sum(values['cached']) / sum(values['input']) * 100,
    }


def calculate(rows: list[dict[str, object]]) -> dict[str, object]:
    groups: dict[str, object] = {}
    for cohort in ('harness_valid', 'all', 'excluded_task3_run1'):
        selected = [row for row in rows if cohort == 'all' or row['cohort'] == cohort]
        groups[cohort] = {v: summarize([r for r in selected if r['variant'] == v]) for v in VARIANTS}
    for task in range(1, 5):
        groups[f'task{task}'] = {
            v: summarize([r for r in rows if r['cohort'] == 'harness_valid' and r['task'] == task and r['variant'] == v])
            for v in VARIANTS
        }
    return groups


def csv_text(groups: dict[str, object]) -> str:
    import io
    columns = ['cohort', 'variant', 'n', 'input_sum', 'cached_sum', 'uncached_sum', 'output_sum', 'total_sum', 'seconds_sum', 'mcp_calls_sum', 'input_mean', 'cached_mean', 'uncached_mean', 'output_mean', 'total_mean', 'seconds_mean', 'mcp_calls_mean', 'total_median', 'seconds_median', 'total_min', 'total_max', 'total_sample_sd', 'seconds_sample_sd', 'cache_pct']
    stream = io.StringIO(newline='')
    writer = csv.DictWriter(stream, fieldnames=columns, lineterminator="\n")
    writer.writeheader()
    for cohort, variants in groups.items():
        for variant, stats in variants.items():
            row = {'cohort': cohort, 'variant': variant, 'n': stats['n'], 'cache_pct': stats['cache_pct']}
            for measure in ('sum', 'mean'):
                for key in KEYS[:-1]:
                    row[f'{key}_{measure}'] = stats[measure][key]
            for key, stat in [('total', 'median'), ('seconds', 'median'), ('total', 'min'), ('total', 'max'), ('total', 'sample_sd'), ('seconds', 'sample_sd')]:
                row[f'{key}_{stat}'] = stats[stat][key]
            writer.writerow(row)
    return stream.getvalue()


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify the checked-in statistics without changing files')
    parser.add_argument('--data-dir', type=Path, default=root / 'data')
    args = parser.parse_args()
    rows = load_rows(args.data_dir / 'run-metrics.csv')
    verify_sources(rows, args.data_dir / 'results')
    groups = calculate(rows)
    json_path = args.data_dir / 'statistics.json'
    csv_path = args.data_dir / 'per-task-statistics.csv'
    generated_csv = csv_text(groups)
    if args.check:
        if json.loads(json_path.read_text()) != groups:
            raise ValueError('Checked-in JSON statistics differ from recalculation')
        with csv_path.open(newline='') as stream:
            if stream.read() != generated_csv:
                raise ValueError('Checked-in CSV statistics differ from recalculation')
        print('Verified 39 runs, 13 source summaries and all aggregate/per-task statistics.')
    else:
        json_path.write_text(json.dumps(groups, indent=2))
        with csv_path.open('w', newline='') as stream:
            stream.write(generated_csv)
        print('Regenerated statistics from 39 case-study rows.')


if __name__ == '__main__':
    main()
