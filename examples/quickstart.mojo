# Hash a buffer three ways and stream it in chunks.
from xxhash import xxh64, xxh3_64, xxh3_128, XXH3


def main():
    var data = List[UInt8](length=1 << 20, fill=42)
    print("xxh64   ", hex(xxh64(data)))
    print("xxh3_64 ", hex(xxh3_64(data)))
    print("xxh3_128", hex(xxh3_128(data)))
    var h = XXH3()
    for i in range(0, len(data), 4096):
        h.update(data[i : i + 4096])
    print("streamed equal:", h.digest64() == xxh3_64(data))
