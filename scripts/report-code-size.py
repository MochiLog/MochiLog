#!/usr/bin/env python3
"""Report tracked application sources with cloc; do not scan build/dependency trees."""
import argparse
import collections
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

REPOS = {
    'mobile': ('MochiLog（iPhone・iPad・Watch）', 'MochiLog-mac-log-transfer'),
    'mac': ('MochiLog Mac', 'MochiLog-Mac'),
    'windows': ('MochiLog Windows', 'MochiLog-Windows'),
    'web': ('MochiLog Web', 'MochiLog-Web'),
}
SOURCE = {'.swift', '.cs', '.xaml', '.py', '.sh', '.command', '.rb', '.c', '.h',
          '.rs', '.ps1', '.iss', '.tsx', '.ts', '.js', '.jsx', '.css'}
LABELS = {'application': 'アプリ実装・UI', 'tests': 'テスト・試験補助',
          'tools': 'ビルド・配信・開発ツール', 'research': '研究・プローブ',
          'localization': '翻訳リソース', 'documentation': '説明資料',
          'configuration': '設定・データ・その他テキスト', 'assets': '画像・バイナリ',
          'external': '外部由来・ライセンス・開発支援素材', 'measurement': '本集計ツール／結果'}
CODE_GROUPS = ('application', 'tests', 'tools', 'research')


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root).decode().strip()


def classify(repo, file):
    p = Path(file)
    parts = p.parts
    lower = file.lower()
    if file == 'scripts/report-code-size.py' or file.startswith('docs/code-size/'):
        return 'measurement'
    if parts[0] in {'.claude', '.shared', '.agent', '.cursor', '.kiro', '.windsurf', 'third_party'} or 'ui-ux-pro-max' in lower or any('licenses' in part.lower() for part in parts[:-1]) or p.name == 'LICENSE':
        return 'external'
    if p.suffix == '.md' or p.suffix == '.html':
        return 'documentation'
    if p.suffix in {'.xcstrings', '.strings'} or file == 'resources/WindowsStrings.json':
        return 'localization'
    if p.suffix in SOURCE or p.name == 'Fastfile':
        if 'research' in parts:
            return 'research'
        if parts[0].lower() in {'tests', 'uitests', 'watchuitests'} or p.name.startswith('test_') or p.name.startswith('test-') or 'scripts/tests/' in file or 'scripts/test-' in file:
            return 'tests'
        if repo == 'web' and p.name in {'vite.config.ts', 'playwright.config.ts'}:
            return 'tools'
        if parts[0] in {'scripts', 'fastlane'} or len(parts) == 1 and (repo == 'mobile' or p.suffix in {'.ps1', '.iss', '.command'}):
            return 'tools'
        return 'application'
    if p.suffix in {'.png', '.ico', '.jpeg', '.jpg', '.gif', '.pdf', '.pyc', '.a', '.zip'}:
        return 'assets'
    return 'configuration'


def count_sources(root, files):
    result = {}
    normal = [f for f in files if Path(f).name != 'Fastfile']
    with tempfile.TemporaryDirectory(prefix='mochilog-code-size-') as tmp:
        file_list = Path(tmp) / 'files.txt'
        file_list.write_text(''.join(f'{root / f}\n' for f in normal))
        batches = [(['--list-file=' + str(file_list), '--force-lang=Bourne Shell,command', '--force-lang=Pascal,iss'], normal)] if normal else []
        batches += [(['--force-lang=Ruby', str(root / f)], [f]) for f in files if Path(f).name == 'Fastfile']
        for args, expected in batches:
            raw = subprocess.check_output(['cloc', '--json', '--by-file', '--skip-uniqueness', '--quiet', *args])
            data = json.loads(raw)
            for name, metric in data.items():
                if name in {'header', 'SUM'}:
                    continue
                relative = str(Path(name).relative_to(root))
                if Path(relative).suffix == '.iss':
                    metric['language'] = 'Inno Setup'
                result[relative] = metric
            missing = set(expected) - set(result)
            if missing:
                raise RuntimeError('cloc did not recognize: ' + ', '.join(sorted(missing)))
    return result


def totals(rows):
    return {key: sum(row[key] for row in rows) for key in ('files', 'code', 'comment', 'blank', 'physical', 'bytes')}


def fmt(value):
    return f'{value:,}'


def table(headers, rows):
    return '| ' + ' | '.join(headers) + ' |\n| ' + ' | '.join('---' for _ in headers) + ' |\n' + ''.join('| ' + ' | '.join(map(str, row)) + ' |\n' for row in rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repos-root', type=Path, default=Path.home() / 'Documents')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = {'measuredAt': datetime.datetime.now().astimezone().isoformat(), 'clocVersion': subprocess.check_output(['cloc', '--version']).decode().strip(), 'apps': {}}
    hashes = collections.defaultdict(list)
    for key, (title, folder) in REPOS.items():
        root = (args.repos_root / folder).resolve()
        files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')[:-1]
        selected = [f for f in files if classify(key, f) in CODE_GROUPS]
        metrics = count_sources(root, selected)
        entries = []
        for file in files:
            raw = (root / file).read_bytes()
            category = classify(key, file)
            row = {'path': file, 'category': category, 'files': 1, 'bytes': len(raw)}
            metric = metrics.get(file, {})
            row.update({n: metric.get(n, 0) for n in ('code', 'comment', 'blank')})
            row['language'] = metric.get('language')
            try:
                row['physical'] = len(raw.decode('utf-8').splitlines())
            except UnicodeDecodeError:
                row['physical'] = 0
            if row['language']:
                hashes[hashlib.sha256(raw).hexdigest()].append((key, file, row['code']))
            if category == 'localization':
                try:
                    obj = json.loads(raw)
                    strings = obj.get('strings', {})
                    row['translationKeys'] = len(strings)
                    row['locales'] = sorted({lang for item in strings.values() for lang in item.get('localizations', {})})
                except (ValueError, TypeError, AttributeError):
                    pass
            entries.append(row)
        report['apps'][key] = {'title': title, 'repository': folder, 'branch': git(root, 'branch', '--show-current'),
                               'commit': git(root, 'rev-parse', 'HEAD'), 'files': entries,
                               'trackedSourceChanges': git(root, 'diff', '--name-only', 'HEAD')}
    unique_rows = [group[0][2] for group in hashes.values()]
    report['exactContentUniqueSourceFiles'] = len(hashes)
    report['exactContentUniqueCodeLines'] = sum(unique_rows)
    report['exactDuplicateGroups'] = [[{'app': key, 'path': file, 'code': count} for key, file, count in group] for group in hashes.values() if len(group) > 1]
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    (out / 'metrics.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    methodology = '''## 集計方法\n\n- Git管理下のファイルのみ。スマホは4.0.0の開発ブランチを1回だけ数え、mainとの二重計上をしない。iPhone／iPad／Duoで共用するコードも重複計上しない。Watchと共有拡張はスマホ版の内訳に含む。\n- コード行数はclocによる空行・コメントを除いた行数。SwiftUI／XAML／CSSなどUI定義も含む。検証専用コードもソースとして数えるため、配布バイナリの構成とは一致しない。\n- テスト、研究、ビルド・配信ツールは実装から分離。JSON／翻訳／設定／ドキュメントを実装行数へ足さない。ただしWebの翻訳がTSXに埋め込まれている部分はTypeScript行数に含む。\n- 外部依存のダウンロード元、生成物、Build／DerivedData／node_modules、画像、実機ログは実装から除外。第三者ライブラリの内部規模は測定しない。取得してパッチするRustライブラリは含めず、リポジトリ内のパッチ用Pythonは開発ツールとして数える。\n- 4リポジトリ合算では同じ内容のコピーも各リポジトリの保守対象として加算する。別途、完全一致するファイルだけを1回とした参考値も掲載。意味が似た移植コードは除去しない。\n- 行数は複雑さ、品質、工数、バイナリ容量を示す指標ではない。文字列、データ定義、書式で増減する。\n- この集計スクリプトと結果は対象外。コミットIDはレポート追加前の測定時点。\n\n'''
    summary_rows = []
    all_code = []
    for key, app in report['apps'].items():
        rows = app['files']
        code_rows = [r for r in rows if r['category'] in CODE_GROUPS]
        all_code += code_rows
        total = totals(code_rows)
        application = totals([r for r in rows if r['category'] == 'application'])
        tests = totals([r for r in rows if r['category'] == 'tests'])
        tools = totals([r for r in rows if r['category'] in {'tools', 'research'}])
        summary_rows.append([f"[{app['title']}]({key}.md)", fmt(application['code']), fmt(tests['code']), fmt(tools['code']), fmt(total['code']), fmt(total['files'])])
        body = f"# {app['title']} コード規模\n\n測定日時: {report['measuredAt']}。cloc {report['clocVersion']}。\n\nリポジトリ: `{app['repository']}` ／ ブランチ: `{app['branch']}`\n\n測定コミット: `{app['commit']}`\n\nアプリ実装は **{fmt(application['code'])}行**、テスト・ツール・研究を含む管理対象ソースは **{fmt(total['code'])}行／{fmt(total['files'])}ファイル**。\n\n"
        body += '## 用途別\n\n' + table(['用途', 'ファイル', 'コード行', 'コメント行', '空行', '全行'], [[LABELS[c], *[fmt(totals([r for r in rows if r['category'] == c])[n]) for n in ('files', 'code', 'comment', 'blank')], fmt(sum(r['code']+r['comment']+r['blank'] for r in rows if r['category'] == c))] for c in CODE_GROUPS])
        body += '\n## 言語別（実装・テスト・ツール・研究の合計）\n\n' + language_table(code_rows)
        components = collections.defaultdict(list)
        for r in rows:
            if r['category'] == 'application':
                parts = Path(r['path']).parts
                component = '/'.join(parts[:2]) if key == 'mobile' and parts[0] == 'MochiLog' else parts[0] if len(parts) > 1 else '収集用Python'
                if key == 'windows':
                    component = '/'.join(parts[:3]) if len(parts)>3 else 'WinUIアプリ直下' if parts[0]=='src' else '収集用Python'
                components[component].append(r)
        body += '\n## 実装の構成\n\n' + table(['範囲', 'ファイル', 'コード行'], [[f'`{component}`', fmt(len(rs)), fmt(sum(r['code'] for r in rs))] for component, rs in sorted(components.items(), key=lambda item: -sum(r['code'] for r in item[1]))])
        body += '\n## 大きい実装ファイル（上位10件）\n\n' + table(['ファイル', '言語', 'コード行'], [[f"`{r['path']}`", r['language'], fmt(r['code'])] for r in sorted((r for r in rows if r['category']=='application'),key=lambda r:-r['code'])[:10]])
        body += '\n## 実装とは別に管理しているファイル\n\n' + table(['区分', 'ファイル', '物理行数（テキストのみ）', '容量KiB'], [[LABELS[c],fmt(totals([r for r in rows if r['category']==c])['files']),fmt(totals([r for r in rows if r['category']==c])['physical']),f"{totals([r for r in rows if r['category']==c])['bytes']/1024:,.1f}"] for c in ('localization','documentation','configuration','assets','external')])
        body += '\n' + methodology + '[全体集計](report.md) · [機械可読な集計・全ファイル内訳](metrics.json)\n'
        (out / f'{key}.md').write_text(body)
    total = totals(all_code)
    summary_rows.append(['**合計**', *[fmt(sum(r['code'] for r in all_code if r['category'] in group)) for group in ({'application'},{'tests'},{'tools','research'})], fmt(total['code']), fmt(total['files'])])
    body = f"# MochiLog 全アプリのコード規模\n\n測定日時: {report['measuredAt']} ／ cloc {report['clocVersion']}。\n\n4リポジトリのアプリ実装は **{fmt(sum(r['code'] for r in all_code if r['category']=='application'))}行**。テスト・開発ツール・研究を含むソース全体は **{fmt(total['code'])}行／{fmt(total['files'])}ファイル**。\n\n"
    body += table(['アプリ', '実装行', 'テスト行', 'ツール・研究行', '総コード行', 'ソースファイル'],summary_rows)
    body += f"\nコメントは{fmt(total['comment'])}行、空行は{fmt(total['blank'])}行。これらを含むソースの全行数は{fmt(total['code']+total['comment']+total['blank'])}行。\n\n完全一致ファイルを横断的に1回だけ数えた参考値は **{fmt(report['exactContentUniqueCodeLines'])}行／{fmt(report['exactContentUniqueSourceFiles'])}ファイル**。通常合計との差はコピーに含まれるコード行であり、そのまま削除できる量を意味しない。\n\n"
    body += '## 全体の言語内訳\n\n' + language_table(all_code)
    body += '\n## 測定対象の状態\n\n' + table(['アプリ','ブランチ','コミット'],[[app['title'],f"`{app['branch']}`",f"`{app['commit']}`"] for app in report['apps'].values()])
    body += '\n' + methodology + '## 再集計\n\n```sh\npython3 scripts/report-code-size.py --repos-root /Users/ryuya/Documents --output docs/code-size/YYYY-MM-DD\n```\n\ncloc 2.10が必要。FastfileはRuby、.commandはShell、Inno Setupの.issはPascalのコメント規則で集計した。全ファイルの分類・言語・コード／コメント／空行・物理行数は [metrics.json](metrics.json) に保存。\n'
    (out / 'report.md').write_text(body)
    print(json.dumps({'output':str(out),'code':total['code'],'files':total['files'],'apps':summary_rows},ensure_ascii=False,indent=2))


def language_table(rows):
    languages = collections.defaultdict(list)
    for row in rows:
        languages[row['language']].append(row)
    return table(['言語','ファイル','コード行','コメント行','空行'],[[lang,*[fmt(totals(rs)[n]) for n in ('files','code','comment','blank')]] for lang,rs in sorted(languages.items(),key=lambda item:-totals(item[1])['code'])])


if __name__ == '__main__':
    main()
