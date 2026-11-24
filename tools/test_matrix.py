"""Run matrix multiplication in RARS with the submission examples and edge cases."""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def check(jar, a, b):
    m, n, p = len(a), len(b), len(b[0])
    assert all(len(row) == n for row in a)
    assert all(len(row) == p for row in b)
    expected = [sum(a[i][k] * b[k][j] for k in range(n))
                for i in range(m) for j in range(p)]
    source = (ROOT / "riscv-matrix-multiply" / "matrix_multiply_rars.s").read_text()
    values = {"M": [m], "N": [n], "P": [p],
              "A": [x for row in a for x in row], "B": [x for row in b for x in row],
              "C": [0] * (m*p)}
    for name, data in values.items():
        source, count = re.subn(rf"^{name}:\s*\.word.*$",
                                f"{name}: .word " + ", ".join(map(str, data)),
                                source, flags=re.M)
        assert count == 1, name
    source = source.replace("li t1, 4", f"li t1, {m*p}")
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "matrix.s"
        path.write_text(source)
        run = subprocess.run(["java", "-jar", str(jar), "nc", "sm", "ae1", "se2",
                              "1000000", str(path)], capture_output=True, text=True,
                             check=True, timeout=30)
        actual = [int(x) for x in run.stdout.split()]
    assert actual == expected, (actual, expected)
    print(f"PASS: {m}x{n} times {n}x{p}: {actual}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rars_jar", type=Path)
    jar = parser.parse_args().rars_jar.resolve()
    examples = [
        ([[1, 2, 3], [4, 5, 6]], [[7, 8], [9, 10], [11, 12]]),
        ([[1, 2, 3, 4], [6, 6, 7, 8], [9, 10, 11, 12]],
         [[2, 1], [-1, 3], [4, -2], [5, 0]]),
        ([[-3]], [[7]]),
        ([[0, 0, 0]], [[1], [-5], [9]]),
        ([[2, -1], [-3, 4]], [[-5, 0, 2], [1, -2, 3]]),
    ]
    for a, b in examples:
        check(jar, a, b)


if __name__ == "__main__":
    main()
