#!/usr/bin/env python3
import argparse
import re
from itertools import chain
from pathlib import Path

def make_path_set(path: str):
    if path.endswith('/index.html'):
        return (path, path[0:-10], path[0:-11])
    else:
        return (path,)

parser = argparse.ArgumentParser()
parser.add_argument("path")
args = parser.parse_args()

file_path = Path(args.path)
contents = file_path.read_text()

blob_path = re.search(r'Azure container \$web path (.*)/:', contents)
if not blob_path:
    exit(1)
blob_path = f'/{blob_path.group(1)}'

purge_path_matches = re.finditer(r': (.*): Copied \(replaced existing\)', contents)
purge_paths = list(chain.from_iterable(make_path_set(f'/{x.group(1)}') for x in purge_path_matches))

if len(purge_paths) > 50:
    print(blob_path, '/*', sep='')
    print(blob_path)
else:
    for path in purge_paths:
        print(blob_path, path, sep='')
