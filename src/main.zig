const std = @import("std");
const print = std.debug.print;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);
    // print("Number of args: {}\n", .{args.len});
    // print("Args: {s}\n", .{args});

    if (args.len == 1) {
        print("Not enough args...\n", .{});
        return;
    }

    const config = parseArgs(args[1..]);
}

const Slice = struct {
    start: i32,
    end: i32,
};

const ArgError = error{
    InvalidFormat,
};

fn parseSlice(slice_string: []const u8) ArgError!Slice {
    var lhs_end: usize = 0;
    var rhs_start: usize = 0;

    for (slice_string) |char, i| {
        if (char == ':') {
            lhs_end = i;
            rhs_start = lhs_end + 1;
            break;
        }
    }

    const ParseIntError = std.fmt.ParseIntError;
    var start: i32 = std.fmt.parseInt(i32, slice_string[0..lhs_end], 10) catch |err| {
        switch (err) {
            ParseIntError.Overflow => print("Number too large!\n", .{}),
            ParseIntError.InvalidCharacter => print("Invalid characters where number expected\n", .{}),
        }
        return ArgError.InvalidFormat;
    };
    var end: i32 = std.fmt.parseInt(i32, slice_string[rhs_start..], 10) catch |err| {
        switch (err) {
            ParseIntError.Overflow => print("Number too large!\n", .{}),
            ParseIntError.InvalidCharacter => print("Invalid characters where number expected\n", .{}),
        }
        return ArgError.InvalidFormat;
    };

    return Slice{
        .start = start,
        .end = end,
    };
}

fn parseArgs(args: [][]const u8) !void {
    // The first arg should be the slice
    var slice = parseSlice(args[0]) catch |err| {
        print("Invalid args!\n", .{});
        return;
    };

    // print("Slicing from {} to {}\n", .{ slice.start, slice.end });

    // If the second arg is missing read from stdin
    var stdin = false;
    if (args.len == 1) {
        stdin = true;
    }

    if (stdin) {
        try readFile("-", slice);
    } else {
        try readFile(args[1], slice);
    }
}

fn readFile(path: []const u8, slice: Slice) !void {
    var reader: std.fs.File = undefined;
    if (path[0] == '-') {
        var stdin = std.io.getStdIn();
        reader = stdin;
    } else {
        const fs = std.fs;
        var file = try fs.cwd().openFile(path, .{ .read = true });
        reader = file;
    }

    var in_stream = std.io.bufferedReader(reader.reader()).reader();
    var buf: [4096]u8 = undefined;
    var index: usize = 1;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (index += 1) {
        if (index >= slice.start and index <= slice.end) {
            print("{s}\n", .{line});
        }
    }

    reader.close();
}
