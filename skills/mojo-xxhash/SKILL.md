---
name: mojo-xxhash
description: "Hash bytes fast in Mojo with mojo-xxhash: XXH3-64/128, XXH64, XXH32, seeded and streaming, identical to xxhsum. Use for checksums, dedup keys, cache keys and hash tables over byte data in Mojo (not for security)."
---

# mojo-xxhash

```mojo
from xxhash import xxh3_64, XXH3
var key = xxh3_64(bytes)                 # default choice: fastest, 64-bit
var h = XXH3(seed)                       # big files: stream in chunks
for chunk in chunks: h.update(chunk)
var digest = h.digest128()
```

- Not cryptographic. Use a real hash (SHA-256 in mojo-hashlib) where an attacker picks the input.
- `xxh3_128` returns `UInt128` with the high half first, as `xxhsum -H128` prints it.

Gate: `scripts/ci.sh` (Python xxhash + xxhsum oracle, mutants, api, quickstart).
