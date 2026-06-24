#!/usr/bin/env python3
# mix_helper.py: helper functions for building mix node configuration.

from typing import TypedDict, List, Optional
import json
import argparse
import sys
from pathlib import Path
from typing import TextIO, Dict


class MixInfo(TypedDict):
  peerId: str
  multiAddr: str
  mixPubKey: str
  libp2pPubKey: str

class MixPool(TypedDict):
  version: int
  relays: List[MixInfo]

def merge(pool1: MixPool, pool2: MixPool) -> MixPool:
  pool1['relays'].extend(pool2['relays'])
  return pool1

def as_mix_info(wrapped_debug_info: Dict) -> MixInfo:
  debug_info = wrapped_debug_info['result']['value']
  multi_addrs = debug_info['announceAddresses']
  if len(multi_addrs) > 1:
    print("WARNING: multiple addresses found, using first one", file=sys.stderr)

  return {
    'peerId': debug_info['id'],
    'multiAddr': multi_addrs[0],
    'mixPubKey': debug_info['mixPubKey'],
    'libp2pPubKey': debug_info['libp2pPubKey'],
  }

def as_mix_pool(mix_info: MixInfo) -> MixPool:
  return {
    'version': 1,
    'relays': [mix_info]
  }

def cmd_export(istream: TextIO, ostream: TextIO):
  json.dump(
    as_mix_pool(as_mix_info(json.load(istream))),
    ostream,
    indent=2
  )

def cmd_merge(files: List[Path], ostream: TextIO):
  pool = {
    'version': 1,
    'relays': []
  }

  for file in files:
    with open(file, 'r') as f:
      pool = merge(pool, json.load(f))

  json.dump(pool, ostream, indent=2)

def output(path: Optional[Path]):
  if path is None:
    return sys.stdout
  return open(path, 'w', encoding='utf-8')

def input(path: Optional[Path]):
  if path is None:
    return sys.stdin
  return open(path, 'r', encoding='utf-8')

def main():
  parser = argparse.ArgumentParser()
  subparsers = parser.add_subparsers(dest='command', required=True)

  export_parser = subparsers.add_parser('export', help='Exports information from a mix relay debug endpoint')
  export_parser.add_argument('--input', type=Path)
  export_parser.add_argument('--output', type=Path)

  merge_parser = subparsers.add_parser('merge', help='Merges multiple mix relay information files')
  merge_parser.add_argument('inputs', type=Path, nargs='+')
  merge_parser.add_argument('--output', type=Path)

  args = parser.parse_args()

  if args.command == 'export':
    with output(args.output) as ostream, input(args.input) as istream:
      cmd_export(istream, ostream)

  elif args.command == 'merge':
    with output(args.output) as ostream:
      cmd_merge(args.inputs, ostream)

if __name__ == '__main__':
  main()
