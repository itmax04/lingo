#!/usr/bin/env python3
"""Validate exact native tokens and localized format placeholders without external packages."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parent.parent
system = root / 'design/redesign-2026/design-system'
tokens = json.loads((system / 'tokens.json').read_text())
source = (root / 'Sources/LingoMac/Design/Theme.swift').read_text()
actual = {key: {'light': '#' + light, 'dark': '#' + dark}
          for key, light, dark in re.findall(r'static let (\w+) = adaptive\(0x([0-9A-F]{6}), 0x([0-9A-F]{6})\)', source)}
assert tokens == actual, 'Theme.swift differs from the canonical token manifest'
contrast = json.loads((system / 'contrast.json').read_text())
assert all(pair['ratio'] >= contrast['threshold'] for pair in contrast['checks']), 'Contrast failure'
for copy in [system / 'DESIGN.md', root / 'design/redesign-2026/08-design-system/DESIGN.md']:
    assert copy.read_text() == (root / 'DESIGN.md').read_text(), 'Design system copies differ'
count = 0
for path in (root / 'Resources').glob('*.xcstrings'):
    catalog = json.loads(path.read_text())
    assert catalog['sourceLanguage'] == 'en'
    for key, entry in catalog['strings'].items():
        languages = entry['localizations']
        assert {'en', 'ru'} <= languages.keys(), (path.name, key)
        english = languages['en']['stringUnit']['value']
        russian = languages['ru']['stringUnit']['value']
        pattern = r'%(?:\d+\$)?(?:lld|ld|@|d|f|s)'
        assert re.findall(pattern, english) == re.findall(pattern, russian), (path.name, key, 'format parameters')
        count += 1
print(f'design: PASS ({len(actual)} exact color tokens, {len(contrast["checks"])} contrast pairs, {count} bilingual strings)')
