"""Validate historical-data invariants and the excluded-run boundary."""
import csv
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('analysis', ROOT / 'scripts/analyze.py')
analysis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analysis)


class AnalysisTests(unittest.TestCase):
    def test_published_sources_and_main_totals(self):
        rows = analysis.load_rows(ROOT / 'data/run-metrics.csv')
        analysis.verify_sources(rows, ROOT / 'data/results')
        groups = analysis.calculate(rows)
        self.assertEqual(groups['harness_valid']['baseline']['n'], 12)
        self.assertEqual(groups['harness_valid']['baseline']['sum']['total'], 26031155)
        self.assertEqual(groups['harness_valid']['graft']['sum']['total'], 20579012)
        self.assertEqual(groups['harness_valid']['codegraph']['sum']['total'], 30056342)
        self.assertEqual(groups['excluded_task3_run1']['codegraph']['sum']['total'], 649427)
        self.assertEqual(groups['task3']['baseline']['n'], 3)

    def assert_rejected(self, mutate):
        with (ROOT / 'data/run-metrics.csv').open(newline='') as stream:
            reader = csv.DictReader(stream)
            fields, rows = reader.fieldnames, list(reader)
        mutate(rows)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'runs.csv'
            with path.open('w', newline='') as stream:
                writer = csv.DictWriter(stream, fieldnames=fields)
                writer.writeheader()
                writer.writerows(rows)
            with self.assertRaises(ValueError):
                analysis.load_rows(path)

    def test_cached_input_cannot_exceed_input(self):
        self.assert_rejected(lambda rows: rows[0].update(cached=str(int(rows[0]['input']) + 1)))

    def test_excluded_run_cannot_be_counted_as_valid(self):
        def mutate(rows):
            row = next(r for r in rows if r['cohort'] == 'excluded_task3_run1')
            row['cohort'] = 'harness_valid'
        self.assert_rejected(mutate)

    def test_duplicate_rows_are_rejected(self):
        self.assert_rejected(lambda rows: rows.append(dict(rows[0])))


if __name__ == '__main__':
    unittest.main()
