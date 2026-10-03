#!/usr/bin/env python3
"""Install latest stable Proton Wineland and undo this session's Witcher patch."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def game_closed():
    for comm in Path('/proc').glob('[0-9]*/comm'):
        try:
            name = comm.read_text().strip().lower()
        except OSError:
            continue
        if name == 'witcher3.exe':
            raise SystemExit('Close Witcher 3 first, then run this script again.')


def main():
    game_closed()
    steam = Path.home() / '.local/share/Steam'
    exe = steam / 'steamapps/common/The Witcher 3/bin/x64_dx12/witcher3.exe'
    backup = exe.with_name('witcher3.exe.orig-5.0.0.1044392')
    original = '9406eccc12b68e08920931442ef6a57340e910d3e01f2082e88232487433fe51'
    patched = 'bf690a33a07c9f7d18b3f3df3722729e291f6be657d91973aee0bb25e815d7c4'
    if sha(backup) != original or sha(exe) not in (original, patched):
        raise SystemExit('Executable or backup changed; refusing to overwrite it. Use Steam Verify integrity instead.')

    req = urllib.request.Request(
        'https://api.github.com/repos/nanomatters/proton-cachyos/releases?per_page=30',
        headers={'User-Agent': 'bazzite-setup-wineland'})
    with urllib.request.urlopen(req, timeout=60) as response:
        releases = json.load(response)
    releases = [r for r in releases if not r['draft'] and not r['prerelease']
                and r['tag_name'].startswith('wineland-')]
    release = max(releases, key=lambda r: r['published_at'])
    # This machine's Ryzen 7 9800X3D supports x86-64-v3.
    asset = next(a for a in release['assets']
                 if a['name'].endswith('-x86_64_v3.tar.xz'))
    digest = asset.get('digest', '')
    if not digest.startswith('sha256:'):
        raise SystemExit('GitHub provides no SHA-256 for this archive; verification required before installation.')
    cache = Path.home() / '.cache/witcher3-wineland'
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / asset['name']
    if not archive.exists() or sha(archive) != digest[7:]:
        print('Downloading', asset['name'], flush=True)
        partial = archive.with_suffix('.part')
        with urllib.request.urlopen(asset['browser_download_url'], timeout=120) as response:
            with partial.open('wb') as out:
                shutil.copyfileobj(response, out)
        if sha(partial) != digest[7:]:
            raise SystemExit('Archive checksum mismatch; nothing installed or restored.')
        os.replace(partial, archive)
    print('Archive SHA-256 verified.', flush=True)
    tools = steam / 'compatibilitytools.d'
    tools.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.wineland-stage-', dir=tools) as staging:
        stage = Path(staging)
        with tarfile.open(archive) as tar:
            tar.extractall(stage, filter='data')
        manifests = list(stage.glob('*/compatibilitytool.vdf'))
        if len(manifests) != 1:
            raise SystemExit('Unexpected archive layout; executable not restored.')
        folder = manifests[0].parent
        dest = tools / folder.name
        marker = dest / '.bazzite-wineland-archive-sha256'
        if dest.exists():
            if not marker.exists() or marker.read_text().strip() != digest[7:]:
                raise SystemExit(f'{dest} already exists; refusing to overwrite it.')
        else:
            (folder / marker.name).write_text(digest[7:] + '\n')
            os.rename(folder, dest)
    game_closed()
    if sha(exe) not in (original, patched):
        raise SystemExit('Game executable changed during installation; refusing to restore.')
    with tempfile.NamedTemporaryFile(prefix='witcher3-restore-', dir=exe.parent, delete=False) as f:
        temp = Path(f.name)
    try:
        shutil.copy2(backup, temp)
        if sha(temp) != original:
            raise SystemExit('Restoration verification failed.')
        os.replace(temp, exe)
    finally:
        temp.unlink(missing_ok=True)
    assert sha(exe) == original
    note = exe.with_name('witcher3-dlss-patch.json')
    if note.exists():
        record = json.loads(note.read_text())
        record['status'] = 'restored original executable for Proton Wineland'
        record['current_sha256'] = original
        note.write_text(json.dumps(record, indent=2) + '\n')
    print(f'Installed: {dest}\nOriginal executable restored and verified. Backup retained.')
    print('Fully restart Steam, then select Proton Wineland for Witcher 3 in Properties > Compatibility.')


if __name__ == '__main__':
    main()
