"""Bundle exact enabled Rust dependency license texts with the native diagnostics library."""
import json, subprocess, sys
from pathlib import Path
root, features = Path(sys.argv[1]), sys.argv[2]
metadata=json.loads(subprocess.check_output(['cargo','metadata','--locked','--manifest-path',str(root/'Cargo.toml'),'--format-version','1','--no-default-features','--features','idevice-ffi/'+features.replace(',',',idevice-ffi/'),'--filter-platform','aarch64-apple-ios']))
packages={p['id']:p for p in metadata['packages']}; nodes={n['id']:n for n in metadata['resolve']['nodes']}
start=next(p['id'] for p in packages.values() if p['name']=='idevice-ffi'); selected=set()
def visit(key):
    if key in selected:return
    selected.add(key)
    for dep in nodes[key]['deps']:visit(dep['pkg'])
visit(start)
# cargo metadata resolves all workspace members; tree gives the actual selected build.
tree=subprocess.check_output(['cargo','tree','--locked','--manifest-path',str(root/'ffi/Cargo.toml'),'-p','idevice-ffi','--no-default-features','--features',features,'--target','aarch64-apple-ios','--edges','normal,build','--prefix','none','--format','{p}'],text=True)
compiled={(line.split()[0],line.split()[1].removeprefix('v')) for line in tree.splitlines() if len(line.split())>=2}
selected={key for key in selected if (packages[key]['name'],packages[key]['version']) in compiled}
rows=[]; missing=[]
for key in sorted(selected):
    p=packages[key]; folder=Path(p['manifest_path']).parent
    candidates=[f for f in folder.iterdir() if f.is_file() and (f.name.lower().startswith(('license','licence','copying','notice','copyright')))]
    if p.get('license_file'):
        candidates.append(folder/p['license_file'])
    if not candidates and p['name'] in ('idevice-ffi','idevice'): candidates=[root/'LICENSE.txt']
    if not candidates:
        vendored=Path(__file__).resolve().parents[1]/'third_party/local-diagnostics-licenses'/f"{p['name']}-{p['version']}"
        if vendored.is_dir():candidates=list(vendored.glob('*'))
    if not candidates:missing.append(p['name'])
    rows.append(f"\n## {p['name']} {p['version']} ({p.get('license') or 'see LICENSE'})\n")
    for f in sorted(set(candidates)):
        rows.append('\n'+f.name+'\n'+f.read_text(errors='replace'))
if missing: raise SystemExit('Missing dependency license texts: '+', '.join(missing))
out=Path(__file__).resolve().parents[1]/'MochiLog/Resources/LICENSE-LocalDiagnostics.txt'
out.write_text('Native local diagnostics: jkcoxson/idevice\nPinned source d32c8189c51c2789496b0768039419c3705498c3; pair-verify-only FFI addition.\n'+''.join(rows))
print('Bundled license texts for', len(selected), 'resolved Rust dependencies')
