#!/usr/bin/env python3
import argparse
import subprocess
import re
import sys
import time

SUCCESS_PATTERNS = [
    r"Reached target.*Graphical",
    r"Reached target.*Multi-User",
    r"localhost login:",
]


def boot_and_monitor(iso_path, timeout=300):
    qemu_cmd = [
        "qemu-system-x86_64",
        "-enable-kvm",
        "-m", "4096",
        "-cdrom", iso_path,
        "-nographic",
        "-serial", "mon:stdio",
    ]

    print(f"Booting ISO: {iso_path}")
    print(f"Timeout: {timeout}s")
    print(f"Looking for patterns: {SUCCESS_PATTERNS}")
    print("-" * 60)

    start_time = time.time()
    with subprocess.Popen(qemu_cmd, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True) as proc:
        while time.time() - start_time < timeout:
            line = proc.stdout.readline()
            if not line:
                break
            print(line, end='')  # Echo to stdout
            for pattern in SUCCESS_PATTERNS:
                if re.search(pattern, line):
                    print("-" * 60)
                    print(f"SUCCESS: Matched pattern '{pattern}'")
                    proc.terminate()
                    return True
        proc.terminate()
        print("-" * 60)
        print(f"FAILED: Timeout after {timeout}s without matching any success pattern")
        return False


def main():
    parser = argparse.ArgumentParser(description="Boot ISO in QEMU and verify it reaches a target")
    parser.add_argument("iso", help="Path to the ISO file")
    parser.add_argument("--timeout", type=int, default=300, help="Timeout in seconds (default: 300)")
    args = parser.parse_args()

    success = boot_and_monitor(args.iso, timeout=args.timeout)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
