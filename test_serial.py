#!/usr/bin/env python3
"""Hardware test for macOS/Linux, using only Python's standard library."""
import argparse
import json
import random
import secrets
import time
from pathlib import Path
from host.serial_client import SerialClient

PREFIX = b"TANG20K ECHO: "

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default="/dev/cu.usbserial-20250303171")
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--report", default="build/hardware-test.json")
    args = parser.parse_args()
    if args.count < 0:
        parser.error("--count must be nonnegative")
    results = []
    with SerialClient(args.port) as device:
        nonce = ("probe-" + secrets.token_hex(12)).encode()
        cases = [(nonce, PREFIX+nonce+b"\r\n"),
                 (b"", PREFIX+b"\r\n"),
                 (b"CRLF\r", PREFIX+b"CRLF\r\n"),
                 (b"X"*120, PREFIX+b"X"*120+b"\r\n"),
                 (b"Y"*121, b"TANG20K ERROR: TOO LONG\r\n"),
                 (b"recovery", PREFIX+b"recovery\r\n")]
        rng = random.Random(20)
        alphabet = bytes(b for b in range(256) if b not in (10,13))
        for i in range(args.count):
            payload = bytes(rng.choices(alphabet, k=rng.randrange(1,121)))
            cases.append((payload, PREFIX+payload+b"\r\n"))
        for i, (payload, expected) in enumerate(cases):
            start = time.monotonic()
            actual = device.request_line(payload)
            elapsed = (time.monotonic()-start)*1000
            if actual != expected:
                raise AssertionError(f"Case {i}: expected {expected!r}, got {actual!r}")
            results.append({"case":i,"tx_hex":payload.hex(),"rx_hex":actual.hex(),"roundtrip_ms":round(elapsed,3)})
            if i == 0:
                print(f"TX: {payload!r}\nRX: {actual!r}")
        report = {"port":args.port,"baud":115200,"format":"8N1","local_echo":False,
                  "passed":len(results),"results":results}
        path = Path(args.report)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(report, indent=2)+"\n")
        print(f"PASS: {len(results)} exchanges on {args.port}; report: {path}")

if __name__ == "__main__":
    main()
