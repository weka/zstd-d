module zstd.compress;

import std.exception;

import zstd.c.zstd;
import zstd.common;

public enum Level : int {
    base = 3,
    mix = 1,
    max = 22,
    speed = 1,
    size = 22,
}

public auto compressBound(size_t srcLength) {
    return ZSTD_compressBound(srcLength);
}

public ubyte[] compress(const(void)[] src, int level = Level.base) {
    auto destCap = compressBound(src.length);
    auto destBuf = new ubyte[destCap];
    return compress(src, destBuf, level);
}

public ubyte[] compress(const(void)[] src, ubyte[] dest, int level = Level.base) {
    auto result = ZSTD_compress(dest.ptr, dest.length, src.ptr, src.length, level);
    if (ZSTD_isError(result)) {
        throw new ZstdException(result);
    }

    return dest[0..result];
}

public class Compressor {
    import core.sys.posix.sys.mman;
    private int level = Level.base;
    private void* workspace;
    private size_t workspaceSize;
    private ZSTD_CCtx* ctx = null;

    this(int level) {
        this.level = level;

        this.workspaceSize = ZSTD_estimateCCtxSize(level);
        this.workspace = mmap(null, workspaceSize, (PROT_READ | PROT_WRITE), (MAP_PRIVATE | MAP_ANON), -1, 0);
        errnoEnforce(workspace !is null);

        this.ctx = ZSTD_initStaticCCtx(workspace, workspaceSize);
        enforceEx!ZstdException(ctx !is null, "Failed to initialize static compression context");
    }
    this() {
        ctx = ZSTD_createCCtx();
        enforceEx!ZstdException(ctx !is null, "Failed to allocate compression context");
    }
    ~this() {
        if (workspace !is null) {
            munmap(workspace, workspaceSize);
            workspace = null;
            ctx = null; // don't free static memory contexts
        }
        if (ctx !is null) {
            zstdEnforce(ZSTD_freeCCtx(ctx));
        }
    }

    public ubyte[] compress(const(void)[] src, ubyte[] dest) {
        auto result = ZSTD_compressCCtx(ctx, dest.ptr, dest.length, src.ptr, src.length, level);
        zstdEnforce(result);
        return dest[0..result];
    }
}

public class StreamCompressor {
    private ZSTD_CStream* cstream;
    private int level = Level.base;

    public static @property size_t recommendedInSize() @trusted {
        return ZSTD_CStreamInSize();
    }

    public static @property size_t recommendedOutSize() @trusted {
        return ZSTD_CStreamOutSize();
    }

    public this(int level = Level.base)
    in {
        assert(Level.min <= level && level <= Level.max);
    } body {
        cstream = ZSTD_createCStream();
        this.level = level;
    }

    public ~this() {
        if (cstream) {
            ZSTD_freeCStream(cstream);
            cstream = null;
        }
    }

    public void startNew() {
        size_t result = ZSTD_initCStream(cstream, level);
        if (ZSTD_isError(result)) {
            throw new ZstdException(result);
        }
    }

    public bool compress(ref const(void)[] src, ref void[] dest) {
        import std.range : empty;
        ZSTD_inBuffer input = {src.ptr, src.length, 0};
        ZSTD_outBuffer output = {dest.ptr, dest.length, 0};

        size_t code = ZSTD_compressStream(cstream, &output, &input);
        if (ZSTD_isError(code)) {
            throw new ZstdException(code);
        }

        src = src[input.pos .. $];
        dest = dest[0 .. output.pos];
        return (src.empty);
    }

    public bool flush(ref void[] dest) {
        ZSTD_outBuffer output = {dest.ptr, dest.length, 0};

        size_t remainingToFlush = ZSTD_flushStream(cstream, &output);
        if (ZSTD_isError(remainingToFlush)) {
            throw new ZstdException(remainingToFlush);
        }

        dest = dest[0 .. output.pos];
        return (remainingToFlush == 0);
    }

    public bool finish(ref void[] dest) {
        ZSTD_outBuffer output = {dest.ptr, dest.length, 0};

        size_t remainingToFlush = ZSTD_endStream(cstream, &output);
        if (ZSTD_isError(remainingToFlush)) {
            throw new ZstdException(remainingToFlush);
        }

        dest = dest[0 .. output.pos];
        return (remainingToFlush == 0);
    }

    public auto applyCompress(const(void)[] src, void[] dest) {
        return Applier!(const(void)[])(src, dest, &this.compress);
    }
    public auto applyFlush(void[] dest) {
        return Applier!()(dest, &this.flush);
    }
    public auto applyFinish(void[] dest) {
        return Applier!()(dest, &this.finish);
    }
}
