"""Check UI string catalogs for missing translations and incompatible placeholders."""
import collections
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
languages = {'en', 'ja', 'zh-Hans', 'zh-Hant', 'ko', 'es', 'fr', 'de'}
pattern = re.compile(r'%(?:(\d+)\$)?(?:[-+#0]*)(?:\d+)?(?:\.\d+)?(hh|ll|h|l|z|j|t|L)?([@diuoxXfFeEgGaAcCsSp%])')

def placeholders(value):
    # Positional placeholders may reorder arguments, but must retain each argument's type.
    result = collections.Counter()
    ordinal = 0
    for match in pattern.finditer(value):
        # Plain prose such as "100% capacity" is not a format argument.
        if match.start() > 0 and value[match.start() - 1].isdigit():
            continue
        position, length, kind = match.groups()
        if kind == '%':
            continue
        ordinal += 1
        result[(int(position) if position else ordinal, (length or '') + kind)] += 1
    for key in re.findall(r'\{[a-zA-Z_]+\}', value):
        result[key] += 1
    return result

errors = []
count = 0
paths = sorted(root.glob('MochiLog/Resources/strings/*.xcstrings')) + sorted(root.glob('MochiLog/Resources/InfoPlist.xcstrings')) + sorted(root.glob('MochiLog Watch App/*.xcstrings')) + sorted(root.glob('Shared/*.xcstrings'))
for path in paths:
    catalog = json.loads(path.read_text(encoding='utf-8'))
    for key, entry in catalog['strings'].items():
        count += 1
        loc = entry.get('localizations', {})
        missing = languages - loc.keys()
        if missing:
            errors.append(f'{path.name} / {key}: missing {sorted(missing)}')
            continue
        expected = placeholders(loc['en']['stringUnit']['value'])
        for language in sorted(languages):
            unit = loc[language].get('stringUnit', {})
            if unit.get('state') != 'translated':
                errors.append(f'{path.name} / {key} / {language}: not translated')
            value = unit.get('value', '')
            if placeholders(value) != expected:
                errors.append(f'{path.name} / {key} / {language}: placeholder mismatch {value!r} vs {loc["en"]["stringUnit"]["value"]!r}')
            if not value and loc['en']['stringUnit']['value']:
                errors.append(f'{path.name} / {key} / {language}: empty translation')
# Verify that literal calls in production code actually point at catalog entries.
# The language-coverage check alone cannot catch a misspelled lookup key.
catalog_keys = {path: set(json.loads(path.read_text(encoding='utf-8'))['strings']) for path in paths}
checked_calls = 0
for directory in ['MochiLog', 'MochiLog Watch App', 'Shared']:
    for swift in (root / directory).rglob('*.swift'):
        source = swift.read_text(encoding='utf-8')
        for match in re.finditer(r'L10n\.(?:string|text)\(', source):
            start = match.end()
            depth, quoted, escaped = 1, False, False
            end = start
            while end < len(source) and depth:
                char = source[end]
                if quoted:
                    if escaped:
                        escaped = False
                    elif char == '\\':
                        escaped = True
                    elif char == '"':
                        quoted = False
                elif char == '"':
                    quoted = True
                elif char == '(':
                    depth += 1
                elif char == ')':
                    depth -= 1
                end += 1
            arguments = source[start:end - 1]
            literal = re.match(r'\s*("(?:\\.|[^"\\])*")', arguments)
            if not literal or '\\(' in literal.group(1):
                continue
            key = json.loads(literal.group(1))
            table_match = re.search(r'\btable:\s*"([^"]+)"', arguments)
            table = table_match.group(1) if table_match else 'Localizable'
            if directory == 'Shared':
                candidates = paths
            else:
                candidates = [path for path in paths if path.relative_to(root).parts[0] in [directory, 'Shared']]
            available = set().union(*(catalog_keys[path] for path in candidates if path.stem == table))
            checked_calls += 1
            if key not in available:
                line = source.count('\n', 0, match.start()) + 1
                errors.append(f'{swift.relative_to(root)}:{line}: missing lookup {table}/{key}')
if errors:
    print('\n'.join(errors))
    raise SystemExit(f'FAIL: {len(errors)} errors')
print(f'PASS: {count} strings across {len(paths)} catalogs, all 8 languages and placeholders checked; {checked_calls} literal lookups verified')
