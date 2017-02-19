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
    compressor.startNew();
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
    decompressor.startNew();
    foreach(buf; decompressor.applyDecompress(compressed, buffer)) {
        decompressed ~= buf;
    }
    std.stdio.writefln("Done.");

    assert(original == decompressed);

    // again
    compressed.length = 0;
    decompressed.length = 0;
    std.stdio.writef("Start compressing... ");
    compressor.startNew();
    foreach(buf; compressor.applyCompress(original, buffer)) {
        compressed ~= buf;
    }
    foreach(buf; compressor.applyFinish(buffer)) {
        compressed ~= buf;
    }
    std.stdio.writefln("Done.");
    std.stdio.writef("Start decompressing... ");
    decompressor.startNew();
    foreach(buf; decompressor.applyDecompress(compressed, buffer)) {
        decompressed ~= buf;
    }
    std.stdio.writefln("Done.");

    assert(original == decompressed);
}
