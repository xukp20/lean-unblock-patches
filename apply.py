#!/usr/bin/env python3
"""Apply or verify the patch set in a private checkout of the official tag."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    here = Path(__file__).resolve().parent
    versions = json.loads((here / 'versions.json').read_text())['versions']
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tag', choices=versions)
    parser.add_argument('checkout', type=Path)
    parser.add_argument('--verify', action='store_true', help='check an already patched tree')
    args = parser.parse_args()
    row = versions[args.tag]
    tree = args.checkout.resolve()

    def git(*argv):
        return subprocess.check_output(['git', '-C', tree, *argv], text=True).strip()

    base = row['official_commit']
    if Path(git('rev-parse', '--show-toplevel')) != tree:
        parser.error('use the checkout root')
    if git('rev-parse', 'HEAD') != base or git('rev-parse', '--abbrev-ref', 'HEAD') != 'HEAD':
        parser.error('check out the official tag in detached mode')
    if not args.verify:
        if git('status', '--porcelain', '--untracked-files=all'):
            parser.error('expected a clean checkout')
        patches = [str(here / name) for name in row['patches']]
        git('apply', '--check', *patches)
        git('apply', *patches)

    expected = row['patched_files_sha256']
    changed = set(git('diff', '--name-only', 'HEAD').splitlines())
    if changed != set(expected) or any(
        hashlib.sha256((tree / name).read_bytes()).hexdigest() != digest
        for name, digest in expected.items()
    ):
        raise SystemExit('source differs from the pinned fork tree; inspect this checkout')
    print(f'{args.tag}: verified the patched source tree at official HEAD {base}')


if __name__ == '__main__':
    main()
