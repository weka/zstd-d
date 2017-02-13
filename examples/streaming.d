import zstd;
static import std.file;
static import std.stdio;

void main(string[] args) {
    import std.functional : partial;
    import std.algorithm : max;

    if (args.length <= 1) {
        throw new Exception("Must specify filename");
    }
    immutable bufSize = max(StreamCompressor.recommendedOutSize, StreamDecompressor.recommendedOutSize);
    void[] buffer = new ubyte[bufSize];
    const(void)[] original = std.file.read(args[1]);

    // compress
    std.stdio.writef("Start compressing... ");
    auto compressor = new StreamCompressor(6);
    void[] compressed;
    compressed.reserve(original.length);
    foreach(buf; compressor.applyCompress(original, buffer)) {
        compressed ~= buf;
    }
    foreach(buf; compressor.applyFinish(buffer)) {
        compressed ~= buf;
    }
    std.stdio.writefln("Done.");

    // decompress
    std.stdio.writef("Start decompressing... ");
    auto decompressor = new StreamDecompressor();
    void[] decompressed;
    decompressed.reserve(original.length);
    foreach(buf; decompressor.applyDecompress(compressed, buffer)) {
        decompressed ~= buf;
    }
    foreach(buf; decompressor.applyFinish(buffer)) {
        //assert(false);
        decompressed ~= buf;
    }
    std.stdio.writefln("Done.");

    assert(original == decompressed);
}
