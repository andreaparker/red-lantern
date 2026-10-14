"""Exercise the recovery helper without applying any display adjustments."""

import random
import struct
import subprocess
import sys


def check(payload, expected):
    result = subprocess.run(
        [sys.argv[1]], input=payload, capture_output=True, timeout=5, check=False
    )
    if result.returncode != expected:
        raise AssertionError(f"helper exited {result.returncode}, expected {expected}")
    if result.stderr:
        raise AssertionError(result.stderr.decode(errors="replace"))


def record(samples):
    return struct.pack("<II", 0, samples) + bytes(samples * 12)


def check_headers():
    cases = [b"", b"\x01", b"\x01\x00", b"\x01\x00\x00"]
    for count in [0, 33, 0xFFFFFFFF]:
        cases.append(struct.pack("<I", count))
    for payload in cases:
        check(payload, 1)
    return len(cases)


def check_bounds():
    for samples in [0, 65537, 0xFFFFFFFF]:
        check(struct.pack("<III", 1, 0, samples), 1)
    for samples in [1, 16, 256, 1024, 65536]:
        check(struct.pack("<I", 1) + record(samples) + b"\x01", 0)
    check(struct.pack("<I", 2) + record(1) + record(16) + b"\x01", 0)
    return 9


def check_truncation():
    generator = random.Random(0)
    for _ in range(100):
        samples = generator.randint(16, 1024)
        count = generator.randrange(samples * 12)
        payload = struct.pack("<III", 1, 0, samples) + generator.randbytes(count)
        check(payload, 1)
    return 100


count = check_headers() + check_bounds() + check_truncation()
print(f"PASS: {count} bounded/truncated helper-protocol cases; no display writes")
