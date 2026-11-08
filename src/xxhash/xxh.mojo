"""xxHash 0.8.4 in pure Mojo: XXH32, XXH64, XXH3-64, XXH3-128 (seeded, one-shot and streaming)."""
from std.builtin.globals import global_constant
from std.sys import is_little_endian


comptime P32_1: UInt32 = 0x9E3779B1
comptime P32_2: UInt32 = 0x85EBCA77
comptime P32_3: UInt32 = 0xC2B2AE3D
comptime P32_4: UInt32 = 0x27D4EB2F
comptime P32_5: UInt32 = 0x165667B1
comptime P64_1: UInt64 = 0x9E3779B185EBCA87
comptime P64_2: UInt64 = 0xC2B2AE3D27D4EB4F
comptime P64_3: UInt64 = 0x165667B19E3779F9
comptime P64_4: UInt64 = 0x85EBCA77C2B2AE63
comptime P64_5: UInt64 = 0x27D4EB2F165667C5
comptime MX1: UInt64 = 0x165667919E3779F9
comptime MX2: UInt64 = 0x9FB21C651E98DF25
# The default secret, padded to 256 bytes: as a SIMD constant it sits 64-byte aligned in static memory,
# so the 64-byte secret loads never split a cache line.
comptime _SECRET_V = SIMD[DType.uint8, 256](0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe, 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c, 0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb, 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f, 0xcb, 0x79, 0xe6, 0x4e, 0xcc, 0xc0, 0xe5, 0x78, 0x82, 0x5a, 0xd0, 0x7d, 0xcc, 0xff, 0x72, 0x21, 0xb8, 0x08, 0x46, 0x74, 0xf7, 0x43, 0x24, 0x8e, 0xe0, 0x35, 0x90, 0xe6, 0x81, 0x3a, 0x26, 0x4c, 0x3c, 0x28, 0x52, 0xbb, 0x91, 0xc3, 0x00, 0xcb, 0x88, 0xd0, 0x65, 0x8b, 0x1b, 0x53, 0x2e, 0xa3, 0x71, 0x64, 0x48, 0x97, 0xa2, 0x0d, 0xf9, 0x4e, 0x38, 0x19, 0xef, 0x46, 0xa9, 0xde, 0xac, 0xd8, 0xa8, 0xfa, 0x76, 0x3f, 0xe3, 0x9c, 0x34, 0x3f, 0xf9, 0xdc, 0xbb, 0xc7, 0xc7, 0x0b, 0x4f, 0x1d, 0x8a, 0x51, 0xe0, 0x4b, 0xcd, 0xb4, 0x59, 0x31, 0xc8, 0x9f, 0x7e, 0xc9, 0xd9, 0x78, 0x73, 0x64, 0xea, 0xc5, 0xac, 0x83, 0x34, 0xd3, 0xeb, 0xc3, 0xc5, 0x81, 0xa0, 0xff, 0xfa, 0x13, 0x63, 0xeb, 0x17, 0x0d, 0xdd, 0x51, 0xb7, 0xf0, 0xda, 0x49, 0xd3, 0x16, 0x55, 0x26, 0x29, 0xd4, 0x68, 0x9e, 0x2b, 0x16, 0xbe, 0x58, 0x7d, 0x47, 0xa1, 0xfc, 0x8f, 0xf8, 0xb8, 0xd1, 0x7a, 0xd0, 0x31, 0xce, 0x45, 0xcb, 0x3a, 0x8f, 0x95, 0x16, 0x04, 0x28, 0xaf, 0xd7, 0xfb, 0xca, 0xbb, 0x4b, 0x40, 0x7e, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
comptime _SECRET_LEN = 192
comptime _BLOCK_STRIPES = (_SECRET_LEN - 64) // 8  # 16


# ---------------------------------------------------------------- little helpers
@always_inline
def _r32(p: Pointer[UInt8, _], i: Int) -> UInt32:
    comptime assert is_little_endian(), "mojo-xxhash reads little-endian words: big-endian hosts are not supported"
    return (p.unsafe_offset(i)).unsafe_bitcast[UInt32]().unsafe_load[alignment=1]()


@always_inline
def _r64(p: Pointer[UInt8, _], i: Int) -> UInt64:
    comptime assert is_little_endian(), "mojo-xxhash reads little-endian words: big-endian hosts are not supported"
    return (p.unsafe_offset(i)).unsafe_bitcast[UInt64]().unsafe_load[alignment=1]()


@always_inline
def _rotl32(x: UInt32, r: UInt32) -> UInt32:
    return (x << r) | (x >> (32 - r))


@always_inline
def _rotl64(x: UInt64, r: UInt64) -> UInt64:
    return (x << r) | (x >> (64 - r))


@always_inline
def _swap32(x: UInt32) -> UInt32:
    return ((x << 24) & 0xFF000000) | ((x << 8) & 0x00FF0000) | ((x >> 8) & 0x0000FF00) | ((x >> 24) & 0x000000FF)


@always_inline
def _swap64(x: UInt64) -> UInt64:
    return (UInt64(_swap32(UInt32(x & 0xFFFFFFFF))) << 32) | UInt64(_swap32(UInt32(x >> 32)))


@always_inline
def _mul128(a: UInt64, b: UInt64) -> Tuple[UInt64, UInt64]:
    var p = UInt128(a) * UInt128(b)
    return (UInt64(p & 0xFFFFFFFFFFFFFFFF), UInt64(p >> 64))


@always_inline
def _fold64(a: UInt64, b: UInt64) -> UInt64:
    var m = _mul128(a, b)
    return m[0] ^ m[1]


# ---------------------------------------------------------------- XXH32
@always_inline
def _round32(acc: UInt32, v: UInt32) -> UInt32:
    return _rotl32(acc + v * P32_2, 13) * P32_1


def _xxh32_tail(var h: UInt32, p: Pointer[UInt8, _], var i: Int, n: Int) -> UInt32:
    while i + 4 <= n:
        h = _rotl32(h + _r32(p, i) * P32_3, 17) * P32_4
        i += 4
    while i < n:
        h = _rotl32(h + UInt32(p[i]) * P32_5, 11) * P32_1
        i += 1
    h ^= h >> 15
    h *= P32_2
    h ^= h >> 13
    h *= P32_3
    return h ^ (h >> 16)


def xxh32(data: Span[UInt8, _], seed: UInt32 = 0) -> UInt32:
    var p = data.unsafe_ptr()
    var n = len(data)
    var i = 0
    var h: UInt32
    if n >= 16:
        var v = SIMD[DType.uint32, 4](seed + P32_1 + P32_2, seed + P32_2, seed, seed - P32_1)
        while i + 16 <= n:
            v = _rotl32x4(v + (p.unsafe_offset(i)).unsafe_bitcast[UInt32]().unsafe_load[width=4, alignment=1]() * P32_2) * P32_1
            i += 16
        h = _rotl32(v[0], 1) + _rotl32(v[1], 7) + _rotl32(v[2], 12) + _rotl32(v[3], 18)
    else:
        h = seed + P32_5
    return _xxh32_tail(h + UInt32(n), p, i, n)


@always_inline
def _rotl32x4(x: SIMD[DType.uint32, 4]) -> SIMD[DType.uint32, 4]:
    return (x << 13) | (x >> 19)


# ---------------------------------------------------------------- XXH64
@always_inline
def _round64(acc: UInt64, v: UInt64) -> UInt64:
    return _rotl64(acc + v * P64_2, 31) * P64_1


@always_inline
def _merge64(h: UInt64, v: UInt64) -> UInt64:
    return (h ^ _round64(0, v)) * P64_1 + P64_4


@always_inline
def _avalanche64(var h: UInt64) -> UInt64:
    h ^= h >> 33
    h *= P64_2
    h ^= h >> 29
    h *= P64_3
    return h ^ (h >> 32)


def _xxh64_tail(var h: UInt64, p: Pointer[UInt8, _], var i: Int, n: Int) -> UInt64:
    while i + 8 <= n:
        h = _rotl64(h ^ _round64(0, _r64(p, i)), 27) * P64_1 + P64_4
        i += 8
    if i + 4 <= n:
        h = _rotl64(h ^ (UInt64(_r32(p, i)) * P64_1), 23) * P64_2 + P64_3
        i += 4
    while i < n:
        h = _rotl64(h ^ (UInt64(p[i]) * P64_5), 11) * P64_1
        i += 1
    return _avalanche64(h)


def _xxh64_lanes(v: SIMD[DType.uint64, 4]) -> UInt64:
    var h = _rotl64(v[0], 1) + _rotl64(v[1], 7) + _rotl64(v[2], 12) + _rotl64(v[3], 18)
    for k in range(4):
        h = _merge64(h, v[k])
    return h


@always_inline
def _stripes64(mut v: SIMD[DType.uint64, 4], p: Pointer[UInt8, _], var i: Int, end: Int) -> Int:
    while i + 32 <= end:
        var x = v + (p.unsafe_offset(i)).unsafe_bitcast[UInt64]().unsafe_load[width=4, alignment=1]() * P64_2
        v = ((x << 31) | (x >> 33)) * P64_1
        i += 32
    return i


@always_inline
def _seed4(seed: UInt64) -> SIMD[DType.uint64, 4]:
    return SIMD[DType.uint64, 4](seed + P64_1 + P64_2, seed + P64_2, seed, seed - P64_1)


def xxh64(data: Span[UInt8, _], seed: UInt64 = 0) -> UInt64:
    var p = data.unsafe_ptr()
    var n = len(data)
    var h: UInt64
    var i = 0
    if n >= 32:
        var v = _seed4(seed)
        i = _stripes64(v, p, 0, n)
        h = _xxh64_lanes(v)
    else:
        h = seed + P64_5
    return _xxh64_tail(h + UInt64(n), p, i, n)


struct XXH64(Movable):
    """Streaming XXH64: update() any number of times, then digest(); equals xxh64(all data, seed)."""

    var v: SIMD[DType.uint64, 4]
    var seed: UInt64
    var total: Int
    var buf: List[UInt8]

    def __init__(out self, seed: UInt64 = 0):
        self.v = _seed4(seed)
        self.seed = seed
        self.total = 0
        self.buf = List[UInt8](capacity=32)

    def update(mut self, data: Span[UInt8, _]):
        self.total += len(data)
        var p = data.unsafe_ptr()
        var i = 0
        if len(self.buf) > 0:
            var need = min(32 - len(self.buf), len(data))
            self.buf.extend(data[:need])
            i = need
            if len(self.buf) < 32:
                return
            _ = _stripes64(self.v, self.buf.unsafe_ptr(), 0, 32)
            self.buf.clear()
        i = _stripes64(self.v, p, i, len(data))
        self.buf.extend(data[i:])

    def digest(self) -> UInt64:
        var h = _xxh64_lanes(self.v) if self.total >= 32 else self.seed + P64_5
        return _xxh64_tail(h + UInt64(self.total), self.buf.unsafe_ptr(), 0, len(self.buf))


# ---------------------------------------------------------------- XXH3 core
@always_inline
def _avalanche3(var h: UInt64) -> UInt64:
    h ^= h >> 37
    h *= MX1
    return h ^ (h >> 32)


@always_inline
def _rrmxmx(var h: UInt64, n: Int) -> UInt64:
    h ^= _rotl64(h, 49) ^ _rotl64(h, 24)
    h *= MX2
    h ^= (h >> 35) + UInt64(n)
    h *= MX2
    return h ^ (h >> 28)


@always_inline
def _mix16(p: Pointer[UInt8, _], i: Int, s: Pointer[UInt8, _], j: Int, seed: UInt64) -> UInt64:
    return _fold64(_r64(p, i) ^ (_r64(s, j) + seed), _r64(p, i + 8) ^ (_r64(s, j + 8) - seed))


@always_inline
def _acc512(mut acc: SIMD[DType.uint64, 8], p: Pointer[UInt8, _], s: Pointer[UInt8, _]):
    var d = p.unsafe_bitcast[UInt64]().unsafe_load[width=8, alignment=1]()
    var k = d ^ s.unsafe_bitcast[UInt64]().unsafe_load[width=8, alignment=1]()
    acc += d.shuffle[1, 0, 3, 2, 5, 4, 7, 6]() + (k & 0xFFFFFFFF) * (k >> 32)


@always_inline
def _scramble(mut acc: SIMD[DType.uint64, 8], s: Pointer[UInt8, _]):
    acc = (acc ^ (acc >> 47) ^ s.unsafe_bitcast[UInt64]().unsafe_load[width=8, alignment=1]()) * UInt64(P32_1)


def _init_acc() -> SIMD[DType.uint64, 8]:
    return SIMD[DType.uint64, 8](UInt64(P32_3), P64_1, P64_2, P64_3, P64_4, UInt64(P32_2), P64_5, UInt64(P32_1))


def _merge(acc: SIMD[DType.uint64, 8], s: Pointer[UInt8, _], j: Int, start: UInt64) -> UInt64:
    var r = start
    for k in range(4):
        r += _fold64(acc[2 * k] ^ _r64(s, j + 16 * k), acc[2 * k + 1] ^ _r64(s, j + 16 * k + 8))
    return _avalanche3(r)


def _long_acc(p: Pointer[UInt8, _], n: Int, s: Pointer[UInt8, _]) -> SIMD[DType.uint64, 8]:
    var acc = _init_acc()
    var block = 64 * _BLOCK_STRIPES
    var blocks = (n - 1) // block
    for b in range(blocks):
        for k in range(_BLOCK_STRIPES):
            _acc512(acc, p.unsafe_offset(b * block + 64 * k), s.unsafe_offset(8 * k))
        _scramble(acc, s.unsafe_offset(_SECRET_LEN - 64))
    var stripes = ((n - 1) - block * blocks) // 64
    for k in range(stripes):
        _acc512(acc, p.unsafe_offset(blocks * block + 64 * k), s.unsafe_offset(8 * k))
    _acc512(acc, p.unsafe_offset(n - 64), s.unsafe_offset(_SECRET_LEN - 64 - 7))
    return acc


@always_inline
def _ksec() -> Pointer[UInt8, ImmStaticOrigin]:
    """The default secret, in static memory: no copy, no allocation."""
    return Pointer(to=global_constant[_SECRET_V]()).unsafe_bitcast[UInt8]()


def _secret_for(seed: UInt64) -> Array[UInt8, 192]:
    """The seeded secret, on the stack (only long inputs with a non-zero seed need one)."""
    var out = Array[UInt8, 192](fill=0)
    var k = _ksec()
    for i in range(192):
        out[i] = k[i]
    if seed != 0:
        var p = out.unsafe_ptr()
        for i in range(_SECRET_LEN // 16):
            (p.unsafe_offset(16 * i)).unsafe_bitcast[UInt64]().unsafe_store[alignment=1](_r64(p, 16 * i) + seed)
            (p.unsafe_offset(16 * i + 8)).unsafe_bitcast[UInt64]().unsafe_store[alignment=1](_r64(p, 16 * i + 8) - seed)
    return out^


# ---------------------------------------------------------------- XXH3-64
def _xxh3_64_short(p: Pointer[UInt8, _], n: Int, s: Pointer[UInt8, _], seed: UInt64) -> UInt64:
    """n <= 240, with the default secret (seed folded in as the reference does)."""
    if n <= 16:
        if n > 8:
            var lo = _r64(p, 0) ^ ((_r64(s, 24) ^ _r64(s, 32)) + seed)
            var hi = _r64(p, n - 8) ^ ((_r64(s, 40) ^ _r64(s, 48)) - seed)
            return _avalanche3(UInt64(n) + _swap64(lo) + hi + _fold64(lo, hi))
        if n >= 4:
            var sd = seed ^ (UInt64(_swap32(UInt32(seed & 0xFFFFFFFF))) << 32)
            var x = UInt64(_r32(p, n - 4)) + (UInt64(_r32(p, 0)) << 32)
            return _rrmxmx(x ^ ((_r64(s, 8) ^ _r64(s, 16)) - sd), n)
        if n > 0:
            var c = (UInt32(p[0]) << 16) | (UInt32(p[n >> 1]) << 24) | UInt32(p[n - 1]) | (UInt32(n) << 8)
            return _avalanche64(UInt64(c) ^ (UInt64(_r32(s, 0) ^ _r32(s, 4)) + seed))
        return _avalanche64(seed ^ (_r64(s, 56) ^ _r64(s, 64)))
    var acc = UInt64(n) * P64_1
    if n <= 128:
        if n > 32:
            if n > 64:
                if n > 96:
                    acc += _mix16(p, 48, s, 96, seed) + _mix16(p, n - 64, s, 112, seed)
                acc += _mix16(p, 32, s, 64, seed) + _mix16(p, n - 48, s, 80, seed)
            acc += _mix16(p, 16, s, 32, seed) + _mix16(p, n - 32, s, 48, seed)
        acc += _mix16(p, 0, s, 0, seed) + _mix16(p, n - 16, s, 16, seed)
        return _avalanche3(acc)
    for i in range(8):
        acc += _mix16(p, 16 * i, s, 16 * i, seed)
    var acc_end = _mix16(p, n - 16, s, 136 - 17, seed)
    acc = _avalanche3(acc)
    for i in range(8, n // 16):
        acc_end += _mix16(p, 16 * i, s, 16 * (i - 8) + 3, seed)
    return _avalanche3(acc + acc_end)


def xxh3_64(data: Span[UInt8, _], seed: UInt64 = 0) -> UInt64:
    var p = data.unsafe_ptr()
    var n = len(data)
    if n <= 240:
        return _xxh3_64_short(p, n, _ksec(), seed)
    if seed == 0:
        return _merge(_long_acc(p, n, _ksec()), _ksec(), 11, UInt64(n) * P64_1)
    var sec = _secret_for(seed)
    var acc = _long_acc(p, n, sec.unsafe_ptr())
    return _merge(acc, sec.unsafe_ptr(), 11, UInt64(n) * P64_1)


# ---------------------------------------------------------------- XXH3-128 (low, high)
@always_inline
def _mix32(mut lo: UInt64, mut hi: UInt64, p: Pointer[UInt8, _], a: Int, b: Int, s: Pointer[UInt8, _], j: Int, seed: UInt64):
    lo += _mix16(p, a, s, j, seed)
    lo ^= _r64(p, b) + _r64(p, b + 8)
    hi += _mix16(p, b, s, j + 16, seed)
    hi ^= _r64(p, a) + _r64(p, a + 8)


def _xxh3_128_short(p: Pointer[UInt8, _], n: Int, s: Pointer[UInt8, _], seed: UInt64) -> Tuple[UInt64, UInt64]:
    if n <= 16:
        if n > 8:
            var bl = (_r64(s, 32) ^ _r64(s, 40)) - seed
            var bh = (_r64(s, 48) ^ _r64(s, 56)) + seed
            var ilo = _r64(p, 0)
            var ihi = _r64(p, n - 8)
            var m = _mul128(ilo ^ ihi ^ bl, P64_1)
            var mlo = m[0] + (UInt64(n - 1) << 54)
            ihi ^= bh
            var mhi = m[1] + ihi + UInt64(UInt32(ihi & 0xFFFFFFFF)) * UInt64(P32_2 - 1)
            mlo ^= _swap64(mhi)
            var h = _mul128(mlo, P64_2)
            return (_avalanche3(h[0]), _avalanche3(h[1] + mhi * P64_2))
        if n >= 4:
            var sd = seed ^ (UInt64(_swap32(UInt32(seed & 0xFFFFFFFF))) << 32)
            var x = UInt64(_r32(p, 0)) + (UInt64(_r32(p, n - 4)) << 32)
            var m = _mul128(x ^ ((_r64(s, 16) ^ _r64(s, 24)) + sd), P64_1 + (UInt64(n) << 2))
            var hi = m[1] + (m[0] << 1)
            var lo = m[0] ^ (hi >> 3)
            lo ^= lo >> 35
            lo *= MX2
            lo ^= lo >> 28
            return (lo, _avalanche3(hi))
        if n > 0:
            var cl = (UInt32(p[0]) << 16) | (UInt32(p[n >> 1]) << 24) | UInt32(p[n - 1]) | (UInt32(n) << 8)
            var ch = _rotl32(_swap32(cl), 13)
            var lo = UInt64(cl) ^ (UInt64(_r32(s, 0) ^ _r32(s, 4)) + seed)
            var hi = UInt64(ch) ^ (UInt64(_r32(s, 8) ^ _r32(s, 12)) - seed)
            return (_avalanche64(lo), _avalanche64(hi))
        return (_avalanche64(seed ^ _r64(s, 64) ^ _r64(s, 72)), _avalanche64(seed ^ _r64(s, 80) ^ _r64(s, 88)))
    var lo = UInt64(n) * P64_1
    var hi: UInt64 = 0
    if n <= 128:
        if n > 32:
            if n > 64:
                if n > 96:
                    _mix32(lo, hi, p, 48, n - 64, s, 96, seed)
                _mix32(lo, hi, p, 32, n - 48, s, 64, seed)
            _mix32(lo, hi, p, 16, n - 32, s, 32, seed)
        _mix32(lo, hi, p, 0, n - 16, s, 0, seed)
    else:
        for i in range(32, 160, 32):
            _mix32(lo, hi, p, i - 32, i - 16, s, i - 32, seed)
        lo = _avalanche3(lo)
        hi = _avalanche3(hi)
        var i = 160
        while i <= n:
            _mix32(lo, hi, p, i - 32, i - 16, s, 3 + i - 160, seed)
            i += 32
        _mix32(lo, hi, p, n - 16, n - 32, s, 136 - 17 - 16, UInt64(0) - seed)
    var h_lo = _avalanche3(lo + hi)
    var h_hi = UInt64(0) - _avalanche3(lo * P64_1 + hi * P64_4 + (UInt64(n) - seed) * P64_2)
    return (h_lo, h_hi)


def xxh3_128(data: Span[UInt8, _], seed: UInt64 = 0) -> UInt128:
    """As one 128-bit number: high64 << 64 | low64 (Python xxhash's xxh3_128_intdigest)."""
    var p = data.unsafe_ptr()
    var n = len(data)
    var r: Tuple[UInt64, UInt64]
    if n <= 240:
        r = _xxh3_128_short(p, n, _ksec(), seed)
    else:
        var sec = _secret_for(seed)
        var acc = _long_acc(p, n, sec.unsafe_ptr())
        r = (_merge(acc, sec.unsafe_ptr(), 11, UInt64(n) * P64_1), _merge(acc, sec.unsafe_ptr(), _SECRET_LEN - 64 - 11, ~(UInt64(n) * P64_2)))
    return (UInt128(r[1]) << 64) | UInt128(r[0])


# ---------------------------------------------------------------- XXH3 streaming
def _consume(
    mut acc: SIMD[DType.uint64, 8], mut stripes: Int, s: Pointer[UInt8, _], p: Pointer[UInt8, _]
):
    _acc512(acc, p, s.unsafe_offset(8 * stripes))
    stripes += 1
    if stripes == _BLOCK_STRIPES:
        _scramble(acc, s.unsafe_offset(_SECRET_LEN - 64))
        stripes = 0


struct XXH3(Movable):
    """Streaming XXH3: update() any number of times, then digest64() / digest128(); equal to the one-shot
    hashes of all data. Keeps at most 256 bytes buffered: the final stripe is only consumed at digest."""

    var acc: SIMD[DType.uint64, 8]
    var secret: Array[UInt8, 192]  # inline: no heap allocation per hasher
    var seed: UInt64
    var buf: List[UInt8]
    var last: Array[UInt8, 64]  # the 64 bytes before buf, once stripes were consumed
    var stripes: Int  # in the current block
    var total: Int

    def __init__(out self, seed: UInt64 = 0):
        self.acc = _init_acc()
        self.secret = _secret_for(seed)
        self.seed = seed
        self.buf = List[UInt8](capacity=256)
        self.last = Array[UInt8, 64](fill=0)
        self.stripes = 0
        self.total = 0

    def update(mut self, data: Span[UInt8, _]):
        """Consume whole stripes as soon as more input follows them: the buffer only ever holds the tail
        (at most 256 bytes) and is topped up once per call, never filled with the whole chunk."""
        self.total += len(data)
        if len(self.buf) + len(data) <= 256:
            self.buf.extend(data)
            return
        var d = data.unsafe_ptr()
        var j = 0
        if len(self.buf) > 0:  # top up to 256 and consume it: more input follows, so it holds no final stripe
            j = 256 - len(self.buf)
            self.buf.extend(data[:j])
            var p = self.buf.unsafe_ptr()
            for k in range(4):
                _consume(self.acc, self.stripes, self.secret.unsafe_ptr(), p.unsafe_offset(64 * k))
            for k in range(64):
                self.last[k] = p[192 + k]
            self.buf.clear()  # keeps its capacity: no allocation per buffered call
        var start = j
        while len(data) - j > 256:
            _consume(self.acc, self.stripes, self.secret.unsafe_ptr(), d.unsafe_offset(j))
            j += 64
        if j > start:
            for k in range(64):
                self.last[k] = d[j - 64 + k]
        self.buf.extend(data[j:])

    def _long(self) -> SIMD[DType.uint64, 8]:
        var acc = self.acc
        var st = self.stripes
        var p = self.buf.unsafe_ptr()
        var s = self.secret.unsafe_ptr()
        var n = len(self.buf)
        for k in range((n - 1) // 64):
            _acc512(acc, p.unsafe_offset(64 * k), s.unsafe_offset(8 * st))
            st += 1
            if st == _BLOCK_STRIPES:
                _scramble(acc, s.unsafe_offset(_SECRET_LEN - 64))
                st = 0
        var tail = Array[UInt8, 64](fill=0)  # inline: no heap allocation at digest
        for k in range(64):
            var i = n - 64 + k
            tail[k] = p[i] if i >= 0 else self.last[64 + i]
        _acc512(acc, tail.unsafe_ptr(), s.unsafe_offset(_SECRET_LEN - 64 - 7))
        return acc

    def digest64(self) -> UInt64:
        if self.total <= 240:
            return xxh3_64(self.buf, self.seed)
        return _merge(self._long(), self.secret.unsafe_ptr(), 11, UInt64(self.total) * P64_1)

    def digest128(self) -> UInt128:
        if self.total <= 240:
            return xxh3_128(self.buf, self.seed)
        var acc = self._long()
        var s = self.secret.unsafe_ptr()
        var lo = _merge(acc, s, 11, UInt64(self.total) * P64_1)
        var hi = _merge(acc, s, _SECRET_LEN - 64 - 11, ~(UInt64(self.total) * P64_2))
        return (UInt128(hi) << 64) | UInt128(lo)
