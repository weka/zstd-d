module zstd.decompress;

import std.range : empty;
import zstd.c.zstd;
import zstd.common;

public void[] uncompress(const(void)[] src) {
    auto destCap = ZSTD_getDecompressedSize(src.ptr, src.length);
    if (destCap == 0) {
        throw new ZstdException("Unknown original size. Use stream API");
    }

    auto destBuf = new ubyte[destCap];
    return uncompress(src, destBuf);
}

public void[] uncompress(const(void)[] src, void[] dest) {
    auto result = ZSTD_decompress(dest.ptr, dest.length, src.ptr, src.length);
    if (ZSTD_isError(result)) {
        throw new ZstdException(result);
    }

    return dest[0..result];
}

public class StreamDecompressor {
    private ZSTD_DStream* dstream;

    public static @property size_t recommendedInSize() @trusted {
        return ZSTD_DStreamInSize();
    }
    public static @property size_t recommendedOutSize() @trusted {
        return ZSTD_DStreamOutSize();
    }

    public this() {
        dstream = ZSTD_createDStream();
        size_t result = ZSTD_initDStream(dstream);
        if (ZSTD_isError(result)) {
            throw new ZstdException(result);
        }
    }

    public ~this() {
        closeStream();
    }

    public bool decompress(ref const(void)[] src, ref void[] dest) {
        ZSTD_inBuffer input = {src.ptr, src.length, 0};
        ZSTD_outBuffer output = {dest.ptr, dest.length, 0};

        size_t code = ZSTD_decompressStream(dstream, &output, &input);
        if (ZSTD_isError(code)) {
            throw new ZstdException(code);
        }

        src = src[input.pos .. $];
        dest = dest[0 .. output.pos];
        return (src.empty);
    }

    public bool flush(ref void[] dest) {
        dest = null;
        return true;
    }

    public bool finish(ref void[] dest) {
        closeStream();
        dest = null;
        return true;
    }

    private void closeStream() {
        if (dstream) {
            ZSTD_freeDStream(dstream);
            dstream = null;
        }
    }
}
