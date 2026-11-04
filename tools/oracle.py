"""Oracle: Python xxhash 3.6 (libxxhash 0.8.2) and xxhsum 0.8.4. `oracle.py --list`; `oracle.py NAME DIR`."""
import sys
import xxhash
DATA = bytes((i * 131 + 7) & 255 for i in range(1 << 20))
LENS = list(range(301)) + list(range(301, 4200, 41)) + [1 << 20]
SEEDS = [0, 1, 0x9E3779B1, 2**64 - 1]
def oneshot(_):
    for n in LENS:
        b = DATA[:n]
        for s in SEEDS:
            print(n, s, f"{xxhash.xxh32_intdigest(b, s & 0xFFFFFFFF):08x}", f"{xxhash.xxh64_intdigest(b, s):016x}",
                  f"{xxhash.xxh3_64_intdigest(b, s):016x}", f"{xxhash.xxh3_128_intdigest(b, s):032x}")
def stream(_):
    for n in (0, 1, 31, 32, 33, 240, 241, 255, 256, 257, 320, 1023, 1024, 1025, 1088, 5000, 70000):
        for ch in (1, 7, 63, 64, 65, 255, 256, 257, 1000):
            for s in (0, 2**64 - 1):
                a, b = xxhash.xxh64(seed=s), xxhash.xxh3_64(seed=s)
                for i in range(0, n, ch):
                    a.update(DATA[i:min(i + ch, n)]); b.update(DATA[i:min(i + ch, n)])
                print(n, ch, s, f"{a.intdigest():016x}", f"{b.intdigest():016x}", f"{xxhash.xxh3_128_intdigest(DATA[:n], s):032x}")
def xxhsum(w):
    for n in (0, 100, 241, 5000):
        p = f"{w}/f{n}"; open(p, "wb").write(DATA[:n])
        d = open(p, "rb").read()  # the file the Mojo side reads; digests as xxhsum -H0/1/3/128 prints them
        for a, h in (("0", xxhash.xxh32), ("1", xxhash.xxh64), ("3", xxhash.xxh3_64), ("128", xxhash.xxh3_128)):
            print(n, a, h(d).hexdigest())
S = {"oneshot": oneshot, "stream": stream, "xxhsum": xxhsum}
if sys.argv[1] == "--list": print("\n".join(S))
else: S[sys.argv[1]](sys.argv[2])
