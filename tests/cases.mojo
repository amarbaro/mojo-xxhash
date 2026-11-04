# The Mojo side of tools/oracle.py: `cases SCENARIO DIR` prints the same lines.
from std.sys import argv
from xxhash import xxh32, xxh64, xxh3_64, xxh3_128, XXH64, XXH3


def hx(v: UInt64, w: Int) -> String:
    comptime H = "0123456789abcdef"
    var s = String()
    for k in range(w - 1, -1, -1):
        s += H[byte=Int((v >> UInt64(4 * k)) & 15)]
    return s


def hx128(v: UInt128) -> String:
    return hx(UInt64(v >> 64), 16) + hx(UInt64(v & 0xFFFFFFFFFFFFFFFF), 16)


def main() raises:
    var c = argv()[1]
    var data = List[UInt8](capacity=1 << 20)
    for i in range(1 << 20):
        data.append(UInt8((i * 131 + 7) & 255))
    var seeds: List[UInt64] = [0, 1, 0x9E3779B1, UInt64.MAX]
    if c == "oneshot":
        var lens = List[Int]()
        for n in range(301):
            lens.append(n)
        for n in range(301, 4200, 41):
            lens.append(n)
        lens.append(1 << 20)
        for n in lens:
            var b = Span(data)[:n]
            for s in seeds:
                print(n, s, hx(UInt64(xxh32(b, UInt32(s & 0xFFFFFFFF))), 8), hx(xxh64(b, s), 16), hx(xxh3_64(b, s), 16), hx128(xxh3_128(b, s)))
    elif c == "stream":
        for n in [0, 1, 31, 32, 33, 240, 241, 255, 256, 257, 320, 1023, 1024, 1025, 1088, 5000, 70000]:
            for ch in [1, 7, 63, 64, 65, 255, 256, 257, 1000]:
                for s in [UInt64(0), UInt64.MAX]:
                    var a = XXH64(s)
                    var b = XXH3(s)
                    var i = 0
                    while i < n:
                        var e = min(i + ch, n)
                        a.update(Span(data)[i:e])
                        b.update(Span(data)[i:e])
                        i = e
                    print(n, ch, s, hx(a.digest(), 16), hx(b.digest64(), 16), hx128(b.digest128()))
    elif c == "xxhsum":
        for n in [0, 100, 241, 5000]:
            var b = Span(data)[:n]
            print(n, "0", hx(UInt64(xxh32(b)), 8))
            print(n, "1", hx(xxh64(b), 16))
            print(n, "3", hx(xxh3_64(b), 16))
            print(n, "128", hx128(xxh3_128(b)))
