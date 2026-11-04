# API

`from xxhash import xxh32, xxh64, xxh3_64, xxh3_128, XXH64, XXH3`

| Call | Returns |
|---|---|
| `xxh32(data, seed: UInt32 = 0)` | `UInt32` |
| `xxh64(data, seed: UInt64 = 0)` | `UInt64` |
| `xxh3_64(data, seed: UInt64 = 0)` | `UInt64` (XXH3_64bits_withSeed) |
| `xxh3_128(data, seed: UInt64 = 0)` | `UInt128`, high 64 bits first (Python `xxh3_128_intdigest`) |
| `XXH64(seed: UInt64 = 0)`, `.update(data)`, `.digest()` | streaming XXH64 |
| `XXH3(seed: UInt64 = 0)`, `.update(data)`, `.digest64()`, `.digest128()` | streaming XXH3; digests do not reset the state |

`data` is any `Span[UInt8]` (`List[UInt8]`, `String.as_bytes()`, a mapped file). Values match `xxhsum -H0/-H1/-H3/-H128`.

Little-endian hosts only (a compile-time assert refuses big-endian targets).
