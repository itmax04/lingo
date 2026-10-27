"""Regression checks for real contrast calculations rather than self-reported evidence."""
import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('check_design', ROOT / 'scripts/check-design.py')
design = importlib.util.module_from_spec(spec)
spec.loader.exec_module(design)


class ContrastTests(unittest.TestCase):
    def setUp(self):
        self.tokens = json.loads((ROOT / 'design/redesign-2026/design-system/tokens.json').read_text())

    def test_wcag_reference_values(self):
        self.assertEqual(design.contrast_ratio('#000000', '#FFFFFF'), 21)
        self.assertEqual(design.contrast_ratio('#808080', '#808080'), 1)

    def test_forged_evidence_cannot_hide_bad_tokens(self):
        # The original checker accepted a claimed ratio of 21 even for white-on-white tokens.
        forged = copy.deepcopy(self.tokens)
        forged['textTertiary']['light'] = '#FFFFFF'
        with self.assertRaisesRegex(AssertionError, 'Contrast failure: light textTertiary'):
            design.contrast_checks(forged)

    def test_light_hierarchy_and_all_surfaces_remain_readable(self):
        tertiary = self.tokens['textTertiary']['light']
        secondary = self.tokens['textSecondary']['light']
        self.assertGreater(design.luminance(tertiary), design.luminance(secondary) * 1.2)
        checks = design.contrast_checks(self.tokens)
        self.assertEqual(len(checks), 88)
        self.assertTrue(all(row['ratio'] >= 4.5 for row in checks))


if __name__ == '__main__':
    unittest.main()
