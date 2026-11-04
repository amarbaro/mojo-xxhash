# Design

- **A port of xxhash.h 0.8.4**, path by path (0, 1-3, 4-8, 9-16, 17-128, 129-240 bytes, long), with the 192-byte default secret and the seeded custom secret for long inputs.
- **SIMD where the reference uses it:** the XXH3 stripe step is one `SIMD[uint64, 8]` load, xor, 32x32-bit multiply and lane-swapped add; scramble is one vector op. XXH32/XXH64 run their four lanes as one 4-wide vector. Mojo compiles for the host, so on AVX-512 machines it beats a generic C build.
- **128-bit products** through `UInt128` (one `mul`/`mulx`).
- **No allocation per hash:** the default secret is one 64-byte-aligned SIMD constant in static memory (an `Array` constant landed at offset 40 and split every secret load); a seeded secret is derived on the stack; a streaming `XXH3` keeps secret and tail inline, so its only heap block is the input buffer.
- **Streaming without copies:** XXH3 keeps at most 256 bytes buffered and consumes stripes straight from the caller's data when its buffer is empty; the stripe holding the last byte is consumed only at digest, as the one-shot code does, so the stripe and scramble counts are identical by construction ((len-1)//64 stripes, (len-1)//1024 scrambles).
- Pointer arithmetic and loads use `unsafe_offset` / `unsafe_load` / `unsafe_bitcast`, the spellings both Mojo 1.2 and 1.3 accept.
