#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Opsero Electronic Design Inc.
"""
Golden model of the DVI 1.0 TMDS encoder (section 3.2.3, Figure 3-5) and a
vector generator for the xsim testbench of dvi_tmds_encoder.v.

Writes  <outdir>/tmds_vectors.txt : one line per clock
        "<din hex> <de> <c0> <c1> <expected q_out hex>"
and checks the model itself against:
  * the four control tokens of the spec,
  * known published symbols (black sequence),
  * a full decode round trip and the DC-balance bound for every vector.
"""
import random
import sys
import os

CTRL = {(0, 0): 0b1101010100, (1, 0): 0b0010101011,   # key: (c0, c1)
        (0, 1): 0b0101010100, (1, 1): 0b1010101011}


class TmdsEncoder:
    def __init__(self):
        self.cnt = 0

    def encode(self, d, de, c0=0, c1=0):
        if not de:
            self.cnt = 0
            return CTRL[(c0, c1)]
        n1d = bin(d).count("1")
        xnor = n1d > 4 or (n1d == 4 and (d & 1) == 0)
        qm = d & 1
        prev = d & 1
        for i in range(1, 8):
            b = (d >> i) & 1
            bit = (1 - (prev ^ b)) if xnor else (prev ^ b)
            qm |= bit << i
            prev = bit
        qm8 = 0 if xnor else 1
        n1 = bin(qm).count("1")
        n0 = 8 - n1
        if self.cnt == 0 or n1 == n0:
            q9 = 1 - qm8
            q70 = qm if qm8 else (~qm & 0xFF)
            self.cnt += (n1 - n0) if qm8 else (n0 - n1)
        elif (self.cnt > 0 and n1 > n0) or (self.cnt < 0 and n0 > n1):
            q9 = 1
            q70 = ~qm & 0xFF
            self.cnt += 2 * qm8 + (n0 - n1)
        else:
            q9 = 0
            q70 = qm
            self.cnt += -2 * (1 - qm8) + (n1 - n0)
        return (q9 << 9) | (qm8 << 8) | q70


def decode(q):
    """DVI 1.0 decoder (Figure 3-6) for data symbols."""
    d = q & 0xFF
    if (q >> 9) & 1:
        d = ~d & 0xFF
    out = d & 1
    for i in range(1, 8):
        b = ((d >> i) ^ (d >> (i - 1))) & 1
        if not (q >> 8) & 1:
            b ^= 1
        out |= b << i
    return out


def self_check():
    # control tokens
    for (c0, c1), tok in CTRL.items():
        assert TmdsEncoder().encode(0, 0, c0, c1) == tok
    # Known published symbols: a run of black (0x00) pixels alternates
    # 0b0100000000 (0x100) and 0b1111111111 (0x3FF) - e.g. the DVI/HDMI
    # literature's "black = 0x100/0x3FF".
    e = TmdsEncoder()
    assert [e.encode(0x00, 1) for _ in range(4)] == [0x100, 0x3FF, 0x100, 0x3FF]
    for v in range(256):
        e = TmdsEncoder()
        assert decode(e.encode(v, 1)) == v
    return True


def gen(outdir, n=20000, seed=1):
    random.seed(seed)
    enc = TmdsEncoder()
    lines = []
    i = 0
    max_abs = 0
    while i < n:
        # active run then blanking run, like video lines
        for _ in range(random.randint(1, 300)):
            mode = random.random()
            if mode < 0.15:
                d = random.choice([0x00, 0xFF, 0x10, 0xEF, 0x55, 0xAA])
            else:
                d = random.randint(0, 255)
            q = enc.encode(d, 1)
            assert decode(q) == d
            max_abs = max(max_abs, abs(enc.cnt))
            lines.append("%02x 1 0 0 %03x" % (d, q))
            i += 1
        for _ in range(random.randint(1, 60)):
            c0, c1 = random.randint(0, 1), random.randint(0, 1)
            d = random.randint(0, 255)
            q = enc.encode(d, 0, c0, c1)
            lines.append("%02x 0 %d %d %03x" % (d, c0, c1, q))
            i += 1
    assert max_abs <= 16, max_abs
    with open(os.path.join(outdir, "tmds_vectors.txt"), "w") as f:
        f.write("\n".join(lines) + "\n")
    return len(lines), max_abs


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    self_check()
    n, m = gen(outdir)
    print("model self-check OK; %d vectors written, max |disparity| = %d" % (n, m))
