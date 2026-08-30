#!/usr/bin/env python3
"""Prints a recorded trace readably, for writing keystroke scripts by hand."""
import json
import sys

path = sys.argv[1]
first = int(sys.argv[2]) if len(sys.argv) > 2 else 0
last = int(sys.argv[3]) if len(sys.argv) > 3 else 10**9
width = 110

for line in open(path):
    record = json.loads(line)
    if not first <= record["frame"] <= last:
        continue
    key = record.get("key")
    pressed = "EOF" if key is None else (chr(key) if 32 <= key < 127 else f"#{key}")
    print(f"--- frame {record['frame']} draws={record['draws']} key={pressed}")
    text = record["text"]
    for i in range(0, len(text), width):
        print("   ", text[i:i + width])
