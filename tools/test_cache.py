"""Regression and generated-trace checks against actual ARM instruction execution."""

import random
import unittest

from run_cache import DEFAULT_TRACE, emulate


class CacheTests(unittest.TestCase):
    def test_coursework_trace(self):
        results = emulate()
        self.assertEqual(results["FIFO"]["hits"], 9)
        self.assertEqual(results["LRU"]["hits"] + results["LRU"]["misses"], len(DEFAULT_TRACE))

    def test_cold_repeat_and_conflict_traces(self):
        for trace in ([0], [42] * 40, list(range(16)), [0, 4, 8, 12] * 12,
                      [1, 5, 9, 13, 17] * 10, [0, 1, 2, 3] * 20,
                      [0, 4, 1, 5, 2, 6, 3, 7] * 8, [254, 250, 246] * 30):
            with self.subTest(trace=trace[:12]):
                emulate(trace)

    def test_seeded_generated_traces(self):
        rng = random.Random(40131025)
        for i in range(100):
            trace = [rng.randrange(32) for _ in range(rng.randrange(1, 128))]
            with self.subTest(case=i):
                emulate(trace, seed=rng.randrange(2**32))

    def test_supported_boundaries(self):
        emulate([0] * 255)
        emulate(list(range(255)))

    def test_invalid_traces(self):
        for trace in ([], [255], [-1], [256], [0] * 256):
            with self.subTest(trace=trace[:3]):
                with self.assertRaises(ValueError):
                    emulate(trace)


if __name__ == "__main__":
    unittest.main(verbosity=2)
