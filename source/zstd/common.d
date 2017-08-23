module zstd.common;

import zstd.c.zstd;

class ZstdException : Exception
{
    @trusted
    this(string msg, string filename = __FILE__, size_t line = __LINE__)
    {
        super(msg, filename, line);
    }

    @trusted
    this(size_t code, string filename = __FILE__, size_t line = __LINE__)
    {
        import std.string : fromStringz;
        super(cast(string)ZSTD_getErrorName(code).fromStringz, filename, line);
    }
}
void zstdEnforce(size_t code, string filename = __FILE__, size_t line = __LINE__) {
    if (ZSTD_isError(code)) {
        throw new ZstdException(code, filename, line);
    }
}

@property @trusted string zstdVersion()
{
    import std.conv : text;

    size_t ver = ZSTD_versionNumber();
    return text(ver / 10000 % 100, ".", ver / 100 % 100, ".", ver % 100);
}

// Utility iterator used by stream de\compress classes.
package struct Applier(Args...) {
    private bool delegate(ref Args, ref void[]) func;
    private Args args;
    private void[] outputBuffer;
    private bool done = false;
    private void[] nextOutput = null;

    @disable this(this);
    this(Args args, void[] outputBuffer, bool delegate(ref Args, ref void[]) func) {
        this.func = func;
        this.args = args;
        this.outputBuffer = outputBuffer;
    }

    public @property bool empty() const {
        return (done && nextOutput is null);
    }
    public void[] front() {
        assert (!empty);
        if (nextOutput is null) {
            popFront();
        }
        return nextOutput;
    }
    public void popFront() {
        if (done) {
            nextOutput = null;
        } else {
            nextOutput = outputBuffer[];
            done = func(args, nextOutput);
        }
    }
}
