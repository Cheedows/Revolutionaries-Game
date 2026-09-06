#!/usr/bin/env python3
"""Execute the exported APK's resources in desktop Godot, without editor data."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

with tempfile.TemporaryDirectory() as temporary:
    pack = Path(temporary) / 'exported.zip'
    with zipfile.ZipFile(sys.argv[1]) as apk, zipfile.ZipFile(pack, 'w') as output:
        for name in apk.namelist():
            if name.startswith('assets/') and name != 'assets/assets.sparsepck':
                output.writestr(name.removeprefix('assets/'), apk.read(name))
    result = subprocess.run([
        os.environ.get('GODOT', 'godot'), '--headless', '--main-pack', str(pack),
        '--script', str(Path(__file__).with_suffix('.gd').resolve()),
    ], capture_output=True, text=True, timeout=90)
    print(result.stdout, end='')
    print(result.stderr, end='', file=sys.stderr)
    sys.exit(result.returncode or (1 if 'SCRIPT ERROR' in result.stderr else 0))
