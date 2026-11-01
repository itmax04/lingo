#!/usr/bin/env python3
"""Validate native tokens, computed WCAG contrast and bilingual catalogs with the standard library."""
import json
import re
from pathlib import Path

THRESHOLD = 4.5
TEXT_TOKENS = ('textPrimary', 'textSecondary', 'textTertiary', 'accentGerman', 'accentEnglish', 'statusDanger', 'statusSuccess')
SURFACES = ('bgWindow', 'bgSidebar', 'surfaceCard', 'surfaceBubbleAssistant', 'surfaceRowSelected', 'surfaceControl')


def luminance(hex_color):
    channels = [int(hex_color.lstrip('#')[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return sum(weight * (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
               for c, weight in zip(channels, (0.2126, 0.7152, 0.0722)))


def contrast_ratio(foreground, background):
    a, b = sorted((luminance(foreground), luminance(background)))
    return (b + 0.05) / (a + 0.05)


def contrast_checks(tokens):
    """Required pairs are defined here, so a missing or forged evidence row cannot waive a check."""
    pairs = [(fg, bg) for fg in TEXT_TOKENS for bg in SURFACES]
    pairs += [('iconSend', accent) for accent in ('accentGerman', 'accentEnglish')]
    checks = []
    for theme in ('light', 'dark'):
        for foreground, background in pairs:
            ratio = contrast_ratio(tokens[foreground][theme], tokens[background][theme])
            assert ratio >= THRESHOLD, f'Contrast failure: {theme} {foreground}/{background} = {ratio:.3f}'
            checks.append(dict(theme=theme, foreground=foreground, background=background, ratio=round(ratio, 3), pass_=True))
    # JSON uses "pass", which is a Python keyword.
    return [{('pass' if k == 'pass_' else k): v for k, v in row.items()} for row in checks]


def forms(en, ru, name, key):
    """Pairs of (English, Russian) texts to compare: the plain strings, or every plural form (English one/other, Russian one/few/many/other)."""
    if 'stringUnit' in en and 'stringUnit' in ru:
        return [(en['stringUnit']['value'], ru['stringUnit']['value'])]
    pe, pr = en['variations']['plural'], ru['variations']['plural']
    assert set(pe) == {'one', 'other'} and set(pr) == {'one', 'few', 'many', 'other'}, (name, key, 'plural categories')
    return [(pe['other']['stringUnit']['value'], pr[cat]['stringUnit']['value']) for cat in pr] + [(pe['one']['stringUnit']['value'], pr['one']['stringUnit']['value'])]


def validate(root):
    system = root / 'design/redesign-2026/design-system'
    tokens = json.loads((system / 'tokens.json').read_text())
    source = (root / 'apps/mac/Sources/LingoMac/Design/Theme.swift').read_text()
    actual = {key: {'light': '#' + light, 'dark': '#' + dark}
              for key, light, dark in re.findall(r'static let (\w+) = adaptive\(0x([0-9A-F]{6}), 0x([0-9A-F]{6})\)', source)}
    assert tokens == actual, 'Theme.swift differs from the canonical token manifest'
    checks = contrast_checks(tokens)
    contrast = json.loads((system / 'contrast.json').read_text())
    assert contrast == {'threshold': THRESHOLD, 'checks': checks}, 'contrast.json is stale; regenerate it from tokens.json'
    assert list(root.rglob('DESIGN.md')) == [root / 'DESIGN.md'], 'Keep only the root DESIGN.md'
    count = 0
    for path in (root / 'apps/mac/Resources').glob('*.xcstrings'):
        catalog = json.loads(path.read_text())
        assert catalog['sourceLanguage'] == 'en'
        for key, entry in catalog['strings'].items():
            languages = entry['localizations']
            assert {'en', 'ru'} <= languages.keys(), (path.name, key)
            pattern = r'%(?:\d+\$)?(?:lld|ld|@|d|f|s)'
            for english, russian in forms(languages['en'], languages['ru'], path.name, key):
                assert re.findall(pattern, english) == re.findall(pattern, russian), (path.name, key, 'format parameters')
            count += 1
    print(f'design: PASS ({len(actual)} exact color tokens, {len(checks)} computed contrast pairs, {count} bilingual strings)')


if __name__ == '__main__':
    validate(Path(__file__).resolve().parent.parent)
