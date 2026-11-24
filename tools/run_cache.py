"""Assemble ARM instructions, emulate them, and check an independent cache model."""

import argparse
import json
from pathlib import Path
import re
import struct

from keystone import Ks, KS_ARCH_ARM, KS_MODE_ARM
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_ARM, UC_HOOK_MEM_WRITE
from unicorn.arm_const import UC_ARM_REG_PC, UC_ARM_REG_SP


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "arm-cache-simulator" / "cache_simulator.s"
POLICIES = ("FIFO", "LRU", "MRU", "LFU", "MFU", "Random")
DEFAULT_TRACE = [12, 10, 12, 10, 14, 10, 10, 10, 6, 10, 8, 6, 10, 14, 14, 12]
BASE = 0x10000
SEED = 12345
SYMBOLS = ("_start", "END", "RESULTS", "FINAL_CACHE", "ADDRESSES", "A_COUNT",
           "rand_seed", "CACHE", "STATUS", "CSIZE", "stack_top")


def validate_trace(trace):
    if not 0 < len(trace) <= 255:
        raise ValueError("The byte-sized trace count supports 1..255 accesses.")
    if any(not isinstance(x, int) or not 0 <= x < 255 for x in trace):
        raise ValueError("Tags must be integers in 0..254; 255 is the empty sentinel.")


def reference(trace, policy, seed=SEED):
    """Generic two-way/four-set model using timestamps and access counts."""
    validate_trace(trace)
    sets = [[None, None] for _ in range(4)]
    hits = misses = 0
    for time, tag in enumerate(trace, 1):
        ways = sets[tag % 4]
        hit = next((i for i, entry in enumerate(ways)
                    if entry is not None and entry["tag"] == tag), None)
        if hit is not None:
            hits += 1
            ways[hit]["accessed"] = time
            ways[hit]["frequency"] += 1
            continue
        misses += 1
        victim = next((i for i, entry in enumerate(ways) if entry is None), None)
        if victim is None:
            if policy == "Random":
                seed = ((seed + time + misses) * 69069 + 1) & 0xFFFFFFFF
                victim = seed & 1
            else:
                key = {"FIFO": "inserted", "LRU": "accessed", "MRU": "accessed",
                       "LFU": "frequency", "MFU": "frequency"}[policy]
                choose = max if policy in ("MRU", "MFU") else min
                victim = choose(range(2), key=lambda i: ways[i][key])
        ways[victim] = dict(tag=tag, inserted=time, accessed=time, frequency=1)
    cache = [entry["tag"] if entry else 255 for ways in sets for entry in ways]
    return dict(hits=hits, misses=misses, cache=cache)


def emulate(trace=DEFAULT_TRACE, seed=SEED):
    validate_trace(trace)
    source = SOURCE.read_text(encoding="utf-8")
    source = re.sub(r"^A_COUNT:.*$", f"A_COUNT: .byte {len(trace)}", source, flags=re.M)
    source = re.sub(r"^ADDRESSES:.*$", "ADDRESSES: .byte " + ",".join(map(str, trace)),
                    source, flags=re.M)
    source = re.sub(r"^rand_seed:.*$", f"rand_seed: .word {seed & 0xFFFFFFFF}",
                    source, flags=re.M)
    # Flatten GNU sections into one emulated memory image. CPU instructions stay intact.
    source = re.sub(r"^\.(?:text|data|global|syntax|arm).*$", "", source, flags=re.M)
    source += "\n.balign 4\n.word " + ", ".join(SYMBOLS) + "\n"
    encoding, _ = Ks(KS_ARCH_ARM, KS_MODE_ARM).asm(source, addr=BASE)
    binary = bytes(encoding)
    symbols = dict(zip(SYMBOLS, struct.unpack("<11I", binary[-44:])))
    cpu = Uc(UC_ARCH_ARM, UC_MODE_ARM)
    cpu.mem_map(BASE, 0x10000)
    cpu.mem_write(BASE, binary)
    allowed_writes = [(symbols[name], symbols[name] + size) for name, size in
                      [("CACHE", 8), ("STATUS", 8), ("RESULTS", 48),
                       ("FINAL_CACHE", 48), ("rand_seed", 4)]]
    allowed_writes.append((symbols["stack_top"] - 1024, symbols["stack_top"]))

    def check_write(uc, access, address, size, value, user_data):
        if not any(lo <= address and address + size <= hi for lo, hi in allowed_writes):
            raise AssertionError(f"Write outside cache/state/stack buffers: {address:#x}")

    cpu.hook_add(UC_HOOK_MEM_WRITE, check_write)
    cpu.emu_start(symbols["_start"], symbols["END"], count=1_000_000)
    if cpu.reg_read(UC_ARM_REG_PC) != symbols["END"]:
        raise AssertionError("Simulation did not finish within the instruction limit.")
    if cpu.reg_read(UC_ARM_REG_SP) != symbols["stack_top"]:
        raise AssertionError("Unbalanced stack after the six policies.")
    counts = struct.unpack("<12I", cpu.mem_read(symbols["RESULTS"], 48))
    caches = cpu.mem_read(symbols["FINAL_CACHE"], 48)
    results = {}
    for i, policy in enumerate(POLICIES):
        result = dict(hits=counts[2*i], misses=counts[2*i+1],
                      cache=list(caches[8*i:8*i+8]))
        expected = reference(trace, policy, seed)
        if result != expected:
            raise AssertionError(f"{policy}: ARM={result}, reference={expected}")
        results[policy] = result
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", help="Comma-separated byte-sized block tags")
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    trace = [int(x.strip(), 0) for x in args.trace.split(",")] if args.trace else DEFAULT_TRACE
    results = emulate(trace, args.seed)
    if args.json:
        print(json.dumps(dict(trace=trace, seed=args.seed, policies=results), indent=2))
    else:
        print(f"ARM instruction emulation; {len(trace)} accesses; Random seed={args.seed}")
        print(f"{'Policy':<10} {'Hits':>5} {'Misses':>7} {'Hit rate':>10}")
        for name, result in results.items():
            print(f"{name:<10} {result['hits']:>5} {result['misses']:>7} "
                  f"{result['hits']/len(trace):>9.2%}")
        print("All counters and final cache contents match the Python reference.")


if __name__ == "__main__":
    main()
