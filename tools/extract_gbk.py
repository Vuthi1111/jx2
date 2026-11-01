#!/usr/bin/env python3
"""Extract tar.gz with GBK-encoded member names, converting to UTF-8 for APFS.

Python's tarfile decodes non-UTF-8 names with surrogateescape, so
name.encode('utf-8', 'surrogateescape') recovers the original raw bytes.
"""
import sys
import tarfile

SRC, DST = sys.argv[1], sys.argv[2]

stats = {"total": 0, "ascii": 0, "utf8": 0, "gbk": 0, "skipped": 0}


def fix_name(name: str):
    raw = name.encode("utf-8", "surrogateescape")
    try:
        raw.decode("ascii")
        stats["ascii"] += 1
        return name
    except UnicodeDecodeError:
        pass
    try:
        out = raw.decode("utf-8")
        stats["utf8"] += 1
        return out
    except UnicodeDecodeError:
        pass
    for enc in ("gb18030", "gbk", "big5"):
        try:
            out = raw.decode(enc)
            stats["gbk"] += 1
            return out
        except (UnicodeDecodeError, LookupError):
            continue
    return None  # unrecoverable


with tarfile.open(SRC, "r:gz") as tf:
    for m in tf:
        stats["total"] += 1
        new = fix_name(m.name)
        if new is None:
            stats["skipped"] += 1
            continue
        m.name = new
        # manual sanitization (filter='data' would drop legit absolute symlinks
        # like gs6/settings -> /home/server/gs1/settings)
        if new.startswith("/") or ".." in new.split("/"):
            stats["skipped"] += 1
            print(f"SKIP unsafe path {new}", file=sys.stderr)
            continue
        try:
            tf.extract(m, DST)
        except (OSError, tarfile.TarError) as e:
            stats["skipped"] += 1
            print(f"SKIP {new}: {e}", file=sys.stderr)

print(stats)
