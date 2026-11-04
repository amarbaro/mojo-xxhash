# Every public call once, plus the README example (known vectors from xxhsum 0.8.4).
from xxhash import xxh32, xxh64, xxh3_64, xxh3_128, XXH64, XXH3


def check(ok: Bool, what: String) raises:
    if not ok:
        raise Error("FAIL api: " + what)


def main() raises:
    var empty = List[UInt8]()
    check(xxh32(empty) == 0x02CC5D05, "xxh32 empty")
    check(xxh64(empty) == 0xEF46DB3751D8E999, "xxh64 empty")
    check(xxh3_64(empty) == 0x2D06800538D394C2, "xxh3_64 empty")
    check(xxh3_128(empty) == (UInt128(0x99AA06D3014798D8) << 64 | UInt128(0x6001C324468D497F)), "xxh3_128 empty")
    var b = "hello world".as_bytes()
    var h = XXH3(7)
    h.update(b[:5])
    h.update(b[5:])
    check(h.digest64() == xxh3_64(b, 7) and h.digest128() == xxh3_128(b, 7), "XXH3 streaming")
    var g = XXH64(7)
    g.update(b)
    check(g.digest() == xxh64(b, 7), "XXH64 streaming")
    print("PASS api")
