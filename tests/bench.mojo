# GB/s on 64 MiB and ns per hash on 16 B / 200 B inputs, pure Mojo vs the system libxxhash 0.8.4 as packaged (generic x86-64 build).
from std.ffi import OwnedDLHandle
from std.time import perf_counter_ns
from xxhash import xxh32, xxh64, xxh3_64


def main() raises:
    var lib = OwnedDLHandle("libxxhash.so.0")
    comptime N = 64 << 20
    var data = List[UInt8](capacity=N)
    for i in range(N):
        data.append(UInt8((i * 131 + 7) & 255))
    var p = data.unsafe_ptr()
    var names: List[String] = ["xxh32", "xxh64", "xxh3_64"]
    for a in range(3):
        var best_m = Int.MAX
        var best_c = Int.MAX
        var hm: UInt64 = 0
        var hc: UInt64 = 0
        for _ in range(5):
            var t0 = perf_counter_ns()
            hm = UInt64(xxh32(data)) if a == 0 else (xxh64(data) if a == 1 else xxh3_64(data))
            var t1 = perf_counter_ns()
            hc = UInt64(lib.call["XXH32", UInt32](p, N, UInt32(0))) if a == 0 else (lib.call["XXH64", UInt64](p, N, UInt64(0)) if a == 1 else lib.call["XXH3_64bits", UInt64](p, N))
            var t2 = perf_counter_ns()
            best_m = min(best_m, Int(t1 - t0))
            best_c = min(best_c, Int(t2 - t1))
        if hm != hc:
            raise Error("FAIL bench: " + names[a] + " differs from libxxhash")
        print(names[a], " mojo GB/s", Float64(N) / Float64(best_m), " C GB/s", Float64(N) / Float64(best_c), " ratio", Float64(best_c) / Float64(best_m))
    for size in [16, 200]:
        comptime R = 2_000_000
        var acc: UInt64 = 0
        var t0 = perf_counter_ns()
        for i in range(R):
            acc += xxh3_64(Span(data)[i & 1023 : (i & 1023) + size])
        var t1 = perf_counter_ns()
        for i in range(R):
            acc += lib.call["XXH3_64bits", UInt64](p + (i & 1023), size)
        var t2 = perf_counter_ns()
        print("xxh3_64", size, "B  mojo ns", Float64(t1 - t0) / R, " C ns", Float64(t2 - t1) / R, " (", acc & 1, ")")
