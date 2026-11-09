# mojo-xxhash

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-xxhash/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-xxhash/actions/workflows/ci.yml) [![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-xxhash)](https://github.com/amarbaro/mojo-xxhash/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-xxhash)](https://github.com/amarbaro/mojo-xxhash/blob/main/LICENSE) [![checks](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/amarbaro/mojo-xxhash/badges/checks.json)](https://github.com/amarbaro/mojo-xxhash/actions/workflows/ci.yml)
<!-- /badges -->

xxHash for Mojo in pure Mojo: XXH32, XXH64, XXH3-64 and XXH3-128, seeded, one-shot and streaming, identical to the reference implementation (0.8.x). 405 lines of code (`mojo-loc`), no C library.

Install: `pixi workspace channel add https://conda.modular.com/max https://prefix.dev/amarbaro/amarbaro`, then `pixi add mojo-xxhash` (import `xxhash`). From source: `git clone https://github.com/amarbaro/mojo-xxhash`, then `mojo run -I mojo-xxhash/src app.mojo`.
Toolchains: Mojo 1.2 stable, and the nightly 1.3.0.dev2026110805 in the weekly [mojo-libs](https://github.com/amarbaro/mojo-libs) matrix (36 libraries on stable, 35 on nightly).

```mojo
from xxhash import xxh3_64, xxh3_128, xxh64, XXH3


def main():
    var data = "hello world".as_bytes()
    var h = xxh3_64(data)                  # UInt64
    var k = xxh3_128(data, seed=42)        # UInt128: high64 << 64 | low64
    var s = XXH3()
    s.update(data[:5])
    s.update(data[5:])
    print(s.digest64() == h, xxh64(data) != 0, k != 0)   # True True True: streaming equals one-shot
```

**Checked against** Python `xxhash` 3.6.0 (libxxhash 0.8.2), whose digests equal the `xxhsum` 0.8.4 CLI: all four hashes for every length 0 to 300, every 41st length to 4,200 and 1 MiB, with 4 seeds (1,592 lines), and XXH64 / XXH3 streaming in 9 chunk sizes across every boundary (240/241, 256/257, 1024/1025), all identical (`scripts/check.sh`, each twice). 7 of 7 mutants caught. Builds and passes on Mojo 1.2.0 and the 1.3 nightly.

**Speed** on 64 MiB (7800X3D), against the system `libxxhash` 0.8.4 as Arch packages it (a generic x86-64 build; Mojo compiles for the host CPU):

| | mojo-xxhash | libxxhash | |
|---|---|---|---|
| XXH32 | 10.7 GB/s | 8.3 GB/s | 1.3x |
| XXH64 | 21.3 GB/s | 12.1 GB/s | 1.8x |
| XXH3-64 | 51.6 GB/s | 22.8 GB/s | 2.3x |

Streaming XXH3 in 4 KiB chunks: 38 GB/s. Short inputs: XXH3-64 of 16 B in 2.5 ns and of 200 B in 11.8 ns (the C column in `tests/bench.mojo` includes a dynamic-call overhead, so it is not a fair short-input comparison).

**Limits:** No streaming XXH32 and no custom-secret API: one-shot calls and `XXH64`/`XXH3` take a seed only.

- API: [docs/api.md](docs/api.md) · design: [docs/design.md](docs/design.md) · agent skill: [skills/mojo-xxhash/SKILL.md](skills/mojo-xxhash/SKILL.md)
- License: Apache-2.0 (the algorithm and constants are from xxHash, BSD-2-Clause, Yann Collet; see NOTICE and LICENSE-xxhash)
