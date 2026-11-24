# Microprocessor & Assembly Projects

ARM cache replacement simulation and RISC-V matrix multiplication, developed for
**Microprocessor and Assembly Language** at Amirkabir University of Technology.

**Author:** Mehrdad SheikhAbbasi

| Project | Architecture | Main implementation |
| --- | --- | --- |
| [Cache replacement simulator](arm-cache-simulator/) | ARMv7-A, 32-bit ARM mode | [cache_simulator.s](arm-cache-simulator/cache_simulator.s) |
| [Matrix multiplication](riscv-matrix-multiply/) | RISC-V RV32IM | [matrix_multiply_rars.s](riscv-matrix-multiply/matrix_multiply_rars.s) |

## ARM cache simulator

A tag-level, **four-set, two-way set-associative cache** with eight entries. Each
access selects a set using `tag & 3`; each policy maintains its own replacement
metadata. The program evaluates the same trace under **FIFO, LRU, MRU, LFU, MFU,
and seeded Random**, saving hit/miss counters and final cache contents for all
six policies.

Random is a reproducible baseline for comparing the other algorithms. Which
policy performs best depends on the access trace.

### Run and verify

Python 3.10 or later:

```sh
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
# Linux/macOS:
# source .venv/bin/activate
python -m pip install -r requirements.txt
python tools/run_cache.py
python tools/test_cache.py
```

The runner assembles the ARM source with Keystone and executes the resulting
machine instructions in Unicorn. It compares both the counters and the final
cache state with an independent Python reference model. It also checks that
writes stay within the cache, metadata, result, and stack buffers, that the
program terminates, and that the stack pointer is restored.

```sh
python tools/run_cache.py --trace "0,4,8,0,4,8,1,5,1" --seed 42
python tools/run_cache.py --json
```

For the original 16-access trace and Random seed `12345`:

| Policy | Hits | Misses | Hit rate |
| --- | ---: | ---: | ---: |
| FIFO | 9 | 7 | 56.25% |
| LRU | 10 | 6 | 62.50% |
| MRU | 8 | 8 | 50.00% |
| LFU | 10 | 6 | 62.50% |
| MFU | 8 | 8 | 50.00% |
| Random | 10 | 6 | 62.50% |

The regression suite covers **111 valid traces / 666 policy runs**, including
100 deterministically generated traces, repeated accesses, set conflicts,
fully associative-within-set pressure, all four sets, and supported boundaries.
Five additional invalid-input cases check the runner's input validation.

These results come from ARM instruction emulation. The model tracks cache tags
and replacement behavior; cache timing, cache-line data, write policies, and
physical hardware performance are outside this implementation's scope.

### Model details

- Fixed geometry: four sets, two ways per set.
- Input: 1 to 255 accesses, with block tags from 0 to 254.
- `0xFF` is reserved for an empty entry.
- LFU/MFU insertion frequency is one; frequency ties choose way zero.
- The seeded generator advances when Random must evict from a full set.
- `RESULTS` stores six `(hits, misses)` pairs in policy order.
- `FINAL_CACHE` stores eight tags per policy, grouped by set and way.

### Source history

The [original submission and Persian report](arm-cache-simulator/original/)
are preserved byte-for-byte. The maintained source fixes register/stack handling,
LFU/MFU counter indexing, and Random's within-set victim indexing and register
preservation. It adds persistent per-policy results and reproducible checks.
The report screenshots document the original submission; the table above is
generated from the maintained implementation.

## RISC-V matrix multiplication

The standalone assembly computes an `M x N` by `N x P` integer matrix product
using row-major indexing and standard multiply/add instructions. A companion
[C implementation](riscv-matrix-multiply/matrix_multiply_inline.c) embeds the
RISC-V assembly using GCC extended inline assembly and explicit clobbers.

The RARS version prints the standalone example's result:

```text
58 64 139 154
```

Download `rars1_6.jar` from the official
[RARS v1.6 release](https://github.com/TheThirdOne/rars/releases/tag/v1.6), then:

```sh
java -jar /path/to/rars1_6.jar nc sm ae1 se2 100000 riscv-matrix-multiply/matrix_multiply_rars.s
python tools/test_matrix.py /path/to/rars1_6.jar
```

Five matrix cases check the original examples, signed values, zero inputs, and
rectangular dimensions against a Python arithmetic reference. The inline C file
is retained as a RISC-V GCC example; it has not been compiled or executed in this
verification run.

The [original RISC-V sources and Persian report](riscv-matrix-multiply/original/)
are preserved. The runnable assembly normalizes source formatting, uses RARS's
entry point, and adds result printing and program exit.

## Repository layout

```text
arm-cache-simulator/
  cache_simulator.s
  original/                 Original assembly and report
riscv-matrix-multiply/
  matrix_multiply_rars.s
  matrix_multiply_inline.c
  original/                 Original sources and report
tools/
  run_cache.py              ARM instruction runner and Python cache reference
  test_cache.py             Cache regression suite
  test_matrix.py            RARS matrix checks
docs/
  validation.json           Recorded validation summary
requirements.txt
```
