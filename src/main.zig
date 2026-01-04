const std = @import("std");
const cbu = @import("cbu");
const zeit = @import("zeit");
const base58 = @import("base58");
const b58 = base58.Table.BITCOIN;
const Keccak256 = std.crypto.hash.sha3.Keccak256;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const fields = comptime std.meta.declarations(Operators);
    for (args[1..], 1..) |arg, index| {
        inline for (fields) |field| {
            if (args.len > 1 and arg[0] == '.' and std.mem.eql(u8, field.name, arg[1..])) {
                // const config = if (args.len >= index + 2 and (args[index + 1][0] != '.') and (args[index + 1][0] == '\'' or args[index + 1][0] == '"')) args[index + 1] else "";
                const config = if (args.len >= index + 2 and (args[index + 1][0] != '.')) args[index + 1] else "";
                _ = try cbu.execClipboardValue(allocator, @field(Operators, field.name), config);
            }
        }
    }
}

const Operators = struct {
    pub fn noop(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        _ = allocator;
        _ = data;
        return null;
    }

    pub fn print(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        _ = allocator;
        std.debug.print("{s}\n", .{data});
        return null;
    }

    pub fn lowercase(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const output = try allocator.alloc(u8, data.len);
        return std.ascii.lowerString(output, data);
    }

    pub fn uppercase(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const output = try allocator.alloc(u8, data.len);
        return std.ascii.upperString(output, data);
    }

    pub fn len(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        _ = allocator;
        std.debug.print("{d}\n", .{data.len});
        return null;
    }

    pub fn reverse(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const output = try allocator.alloc(u8, data.len);
        @memcpy(output, data);
        std.mem.reverse(u8, output);
        return output;
    }

    const Quote = enum { Open, Close };

    const Char = union(enum) {
        Value: u8,
        Eat: u8,
    };

    /// Remove whitespace and newline from the clipboard value
    pub fn compact(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const output = try allocator.alloc(u8, data.len);
        var j: usize = 0;
        var quote_state: Quote = .Close;
        var eat_next = false;
        for (data) |c| {
            const char: Char = blk: {
                if (eat_next) {
                    eat_next = false;
                    break :blk .{ .Eat = c };
                }
                break :blk .{ .Value = c };
            };
            eater: switch (char) {
                .Eat => |v| {
                    output[j] = v;
                    j += 1;
                },
                .Value => |v| {
                    switch (v) {
                        '"' => {
                            quote_state = if (quote_state == .Open) .Close else .Open;
                            continue :eater .{ .Eat = c };
                        },
                        '\\' => {
                            if (quote_state == .Open) {
                                eat_next = true;
                            }
                            continue :eater .{ .Eat = c };
                        },
                        ' ', '\n' => {
                            if (quote_state == .Open) {
                                continue :eater .{ .Eat = c };
                            }
                        },
                        else => {
                            continue :eater .{ .Eat = c };
                        },
                    }
                },
            }
        }
        _ = allocator.resize(output, j);

        return output[0..j];
    }

    pub fn fromunix(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const nanoseconds = try std.fmt.parseInt(i98, data, 10) * std.time.ns_per_s;
        const now = zeit.Instant{ .timestamp = nanoseconds, .timezone = &zeit.utc };
        const buf = try allocator.alloc(u8, 19);
        var writer: std.Io.Writer = .fixed(buf);
        try now.time().strftime(&writer, "%d-%m-%Y %H:%M:%S");

        return buf;
    }

    pub fn unixts(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        _ = data;

        var threaded: std.Io.Threaded = .init(allocator);
        defer threaded.deinit();
        const io = threaded.io();
        const _now = try std.Io.Clock.real.now(io);
        const dt = _now.toSeconds();
        const buf = try allocator.alloc(u8, 10);
        var writer: std.Io.Writer = .fixed(buf);
        try writer.print("{d}", .{dt});
        try writer.flush();

        return buf;
    }

    pub fn tob64(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const size = std.base64.standard.Encoder.calcSize(data.len);
        const dest = try allocator.alloc(u8, size);
        _ = std.base64.standard.Encoder.encode(dest, data);
        return dest;
    }

    pub fn fromb64(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const size = try std.base64.standard.Decoder.calcSizeForSlice(data);
        const dest = try allocator.alloc(u8, size);
        try std.base64.standard.Decoder.decode(dest, data);
        return dest;
    }

    pub fn tohex(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const size = std.fmt.count("{x}", .{data});
        const dest = try allocator.alloc(u8, size);
        _ = try std.fmt.bufPrint(dest, "{x}", .{data});
        return dest;
    }

    pub fn fromhex(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const size = data.len / 2;
        const dest = try allocator.alloc(u8, size);
        _ = try std.fmt.hexToBytes(dest, data);
        return dest;
    }

    pub fn numtohex(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const num = try std.fmt.parseInt(i64, data, 10);
        const size = std.fmt.count("{x}", .{num});
        const dest = try allocator.alloc(u8, size);
        _ = try std.fmt.bufPrint(dest, "{x}", .{num});
        return dest;
    }

    pub fn numfromhex(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        const num = try std.fmt.parseInt(i64, data, 16);
        const size = std.fmt.count("{d}", .{num});
        const dest = try allocator.alloc(u8, size);
        _ = try std.fmt.bufPrint(dest, "{d}", .{num});
        return dest;
    }

    pub fn tob58(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        _ = data;
        // _ = allocator;
        var decoded_4rL4R: [32]u8 = .{
            57,  54,  18,  6,   106, 202, 13,  245, 224, 235, 33,  252, 254,
            251, 161, 17,  248, 108, 25,  214, 169, 154, 91,  101, 17,  121,
            235, 82,  175, 197, 144, 145,
        };

        const n = base58.encodedMaxSize(decoded_4rL4R.len);
        const buf = try allocator.alloc(u8, n);
        defer allocator.free(buf);
        const s = b58.encode(buf, &decoded_4rL4R);
        std.debug.print("Encoded: {s}, length: {d}, Decoded: {d}\n, str: {s}", .{ buf, buf.len, s, decoded_4rL4R });
        return null;
    }

    pub fn fromb58(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;
        _ = data;
        // _ = allocator;
        const encoded = "4rL4RCWHz3iNCdCaveD8KcHfV9YWGsqSHFPo7X2zBNwa";

        const n = base58.decodedMaxSize(encoded.len);
        const buf = try allocator.alloc(u8, n);
        defer allocator.free(buf);
        const s = try b58.decode(buf, encoded);
        std.debug.print("Decoded: {any}, length: {d}, Encoded: {d}\n, str: {s}", .{ buf, buf.len, s, encoded });
        return null;
    }

    /// Usage: cbu .arr 'iput=_s,oput=(x.' .print .arr 'iput=(x.,oput={s","' .print
    pub fn arr(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        const cfg = try ArrConfig.parse(config);
        // std.debug.print("{f}\n", .{cfg});
        const _a = try arrParse(allocator, cfg, data);
        defer allocator.free(_a[0]);
        const a = _a[0][0.._a[1]];

        var buf = try allocator.alloc(u8, 256);
        var s: usize = 0;
        var w: []u8 = undefined;
        if (cfg.output_fix != .None) {
            w = try std.fmt.bufPrint(buf[s..], "{c}", .{@intFromEnum(cfg.output_fix)});
            s += w.len;
        }
        for (a, 0..) |b, i| {
            switch (cfg.output_as) {
                .s => {
                    w = try std.fmt.bufPrint(buf[s..], "{c}{s}", .{ b, if (i < a.len - 1) cfg.output_sep else "" });
                },
                .b => {
                    w = try std.fmt.bufPrint(buf[s..], "{d}{s}", .{ b, if (i < a.len - 1) cfg.output_sep else "" });
                },
                .x => {
                    w = try std.fmt.bufPrint(buf[s..], "{x}{s}", .{ b, if (i < a.len - 1) cfg.output_sep else "" });
                },
            }
            s += w.len;
        }
        if (cfg.output_fix != .None) {
            w = try std.fmt.bufPrint(buf[s..], "{c}", .{@intFromEnum(brackets.close(cfg.output_fix))});
            s += w.len;
        }
        buf = try allocator.realloc(buf, s);
        return buf;
    }

    /// Show=x Skip=--- Hide=*
    pub fn view(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        var end_last = std.mem.splitSequence(u8, config, "---");
        const first = end_last.next() orelse config;
        const last = end_last.next() orelse "";
        const buf = try allocator.alloc(u8, data.len);
        defer allocator.free(buf);
        @memcpy(buf, data);
        for (buf, 0..) |item, i| {
            if ((i + 1 <= first.len and std.ascii.isAlphanumeric(first[i])) or (buf.len - i <= last.len and std.ascii.isAlphanumeric(last[i + last.len - buf.len]))) {
                buf[i] = item;
                continue;
            }
            buf[i] = '*';
        }
        std.debug.print("{s}\n", .{buf});
        return null;
    }

    pub fn help(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = data;
        _ = config;
        _ = allocator;

        const fields = comptime std.meta.declarations(Operators);

        var buf: [fields.len * 20]u8 = undefined;

        // var buf = try allocator.alloc(u8, fields.len * 20);
        // defer allocator.free(buf);

        var i: usize = 1;
        var j: usize = 0;

        buf[0] = '\n';
        for (fields) |field| {
            _ = try std.fmt.bufPrint(buf[i..], "{s: <20}", .{field.name});
            i += 18;
            j += 1;
            if (j % 4 == 0) {
                _ = try std.fmt.bufPrint(buf[i..], "\n", .{});
                i += 1;
            }
        }

        std.debug.print("{s}\n", .{buf[0..i]});

        return null;
    }

    /// Ethereum address from https://github.com/Raiden1411/zabi/blob/d3f57adf3367123435deb4abab329421f1fc68d2/src/utils/utils.zig#L72
    pub fn ethaddress(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        _ = config;

        var buf: [40]u8 = undefined;
        const lower = std.ascii.lowerString(&buf, if (std.mem.startsWith(u8, data, "0x")) data[2..] else data);

        var hashed: [Keccak256.digest_length]u8 = undefined;
        Keccak256.hash(lower, &hashed, .{});
        const hex = std.fmt.bytesToHex(hashed, .lower);

        const checksum = try allocator.alloc(u8, 42);
        for (checksum[2..], 0..) |*c, i| {
            const char = lower[i];

            if (try std.fmt.charToDigit(hex[i], 16) > 7) {
                c.* = std.ascii.toUpper(char);
            } else {
                c.* = char;
            }
        }
        @memcpy(checksum[0..2], "0x");

        return checksum;
    }
};

fn arrParse(allocator: std.mem.Allocator, cfg: ArrConfig, data: []const u8) !struct { []u8, usize } {
    var i = if (cfg.input_fix == .None) data.len else data.len - 2;
    var res: []u8 = try allocator.alloc(u8, i);
    if (cfg.input_fix != .None) {
        @memcpy(res, data[1 .. data.len - 1]);
    } else {
        @memcpy(res, data);
    }
    if (!std.mem.eql(u8, cfg.input_sep, "")) {
        var iter = std.mem.splitSequence(u8, res, cfg.input_sep);
        var j: usize = 0;
        while (iter.next()) |item| {
            // std.debug.print("item={s}\n", .{item});
            switch (cfg.input_as) {
                .s => {
                    res[j] = item[0];
                },
                .b => {
                    res[j] = try std.fmt.parseInt(u8, item, 10);
                },
                .x => {
                    res[j] = try std.fmt.parseInt(u8, item, 16);
                },
            }
            j += 1;
        }
        i = j;
    }
    // const t = allocator.resize(res, i); // doesn;t work
    return .{ res, i };
}

const asin = enum {
    s,
    b,
    x,
};

const brackets = enum(u8) {
    None = '\x00',
    square = '[',
    curly = '{',
    round = '(',
    angle = '<',

    pub fn close(self: brackets) closingBrackets {
        return switch (self) {
            .square => closingBrackets.square,
            .curly => closingBrackets.curly,
            .round => closingBrackets.round,
            .angle => closingBrackets.angle,
            .None => closingBrackets.None,
        };
    }
};

const closingBrackets = enum(u8) {
    square = ']',
    curly = '}',
    round = ')',
    angle = '>',
    None = '\x00',
};

const ArrConfig = struct {
    input_fix: brackets = .square,
    output_fix: brackets = .square,
    input_as: asin = .s,
    output_as: asin = .s,
    input_sep: []const u8 = ", ",
    output_sep: []const u8 = ", ",

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("(.input_fix='{c}', .output_fix='{c}', .input_as='{any}', .output_as='{any}', .input_sep='{s}', .output_sep='{s}')", .{
            @intFromEnum(self.input_fix),
            @intFromEnum(self.output_fix),
            self.input_as,
            self.output_as,
            self.input_sep,
            self.output_sep,
        });
    }

    pub fn parse(config: []const u8) anyerror!ArrConfig {
        var arrConfig = ArrConfig{};
        blk: for (config, 0..) |char, i| {
            if (char == '=') {
                if (std.mem.eql(u8, config[i - 4 .. i], "iput")) {
                    arrConfig.input_fix = std.enums.fromInt(brackets, config[i + 1]) orelse .None;
                    arrConfig.input_as = std.meta.stringToEnum(asin, config[i + 2 .. i + 3]) orelse .s;
                    if (config.len <= i + 3) { // tweak this
                        arrConfig.input_sep = "";
                        continue;
                    }
                    const rest = config[i + 3 ..];
                    for (rest, 0..) |char2, j| { // 'iput=[s, ,oput=[s,' 6
                        if (char2 == '=') {
                            arrConfig.input_sep = rest[0 .. j - 5];
                            continue :blk;
                        }
                    }
                    arrConfig.input_sep = config[i + 3 ..];
                } else if (std.mem.eql(u8, config[i - 4 .. i], "oput")) {
                    arrConfig.output_fix = std.enums.fromInt(brackets, config[i + 1]) orelse .None;
                    arrConfig.output_as = std.meta.stringToEnum(asin, config[i + 2 .. i + 3]) orelse .s;
                    if (config.len <= i + 3) { // tweak this
                        arrConfig.output_sep = "";
                        continue;
                    }
                    const rest = config[i + 3 ..];
                    for (rest, 0..) |char2, j| { // 'iput=[s, ,oput=[s,' 6
                        if (char2 == '=') {
                            arrConfig.output_sep = rest[0 .. j - 5];
                            break;
                        }
                    }
                    arrConfig.output_sep = config[i + 3 ..];
                }
            }
        }

        return ArrConfig{
            .input_fix = arrConfig.input_fix,
            .output_fix = arrConfig.output_fix,
            .input_as = arrConfig.input_as,
            .output_as = arrConfig.output_as,
            .input_sep = arrConfig.input_sep,
            .output_sep = arrConfig.output_sep,
        };
    }
};

test "compact" {
    const allocator = std.testing.allocator;
    const input = "Hello, World!";
    const expected = [_]u8{ 'H', 'e', 'l', 'l', 'o', ',', 'W', 'o', 'r', 'l', 'd', '!' };
    const actual = try Operators.compact(allocator, input, "");
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, &expected, actual_value);
    }
}

test "compact with quotes" {
    const allocator = std.testing.allocator;
    const input = "\"Hello, World!\".hi johndoe";
    const expected = [_]u8{ '"', 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', '"', '.', 'h', 'i', 'j', 'o', 'h', 'n', 'd', 'o', 'e' };
    const actual = try Operators.compact(allocator, input, "");
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, &expected, actual_value);
    }
}

test "compact with escaped quotes" {
    const allocator = std.testing.allocator;
    const input = "\"Hello, World!\".hi johndoe";
    const expected = [_]u8{ '"', 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', '"', '.', 'h', 'i', 'j', 'o', 'h', 'n', 'd', 'o', 'e' };
    const actual = try Operators.compact(allocator, input, "");
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, &expected, actual_value);
    }
}

test "json value" {
    const jsn =
        \\[
        \\  {
        \\    "name": "John Doe",
        \\    "age": 30,
        \\    "email address": "john.doe@example.com",
        \\    "key": "value\""
        \\  }
        \\]
        \\
    ;
    const expected =
        \\[{"name":"John Doe","age":30,"email address":"john.doe@example.com","key":"value\""}]
    ;
    const allocator = std.testing.allocator;
    const actual = try Operators.compact(allocator, jsn, "");
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, expected, actual_value);
    }
}

test "default config parse" {
    const input = "";
    const expected = ArrConfig{
        .input_fix = brackets.square,
        .input_as = asin.s,
        .input_sep = ", ",

        .output_fix = .square,
        .output_as = asin.s,
        .output_sep = ", ",
    };
    const actual = try ArrConfig.parse(input);
    try std.testing.expectEqual(expected, actual);
}
test "iput and oput config parse" {
    const input = "iput={b,,oput=<b..";
    const expected = ArrConfig{
        .input_fix = brackets.curly,
        .input_as = asin.b,
        .input_sep = ",",

        .output_fix = brackets.angle,
        .output_as = asin.b,
        .output_sep = "..",
    };

    const actual = try ArrConfig.parse(input);
    // std.debug.print("{f}\n", .{actual});
    try isEqualArrConfig(expected, actual);
}

test "iput config parse" {
    const input = "iput={b";
    const expected = ArrConfig{
        .input_fix = brackets.curly,
        .input_as = asin.b,
        .input_sep = "",

        .output_fix = .square,
        .output_as = asin.s,
        .output_sep = ", ",
    };

    const actual = try ArrConfig.parse(input);
    // std.debug.print("{f}\n", .{actual});
    try isEqualArrConfig(expected, actual);
}

test "oput config parse" {
    const input = "oput=(b-";
    const expected = ArrConfig{
        .input_fix = brackets.square,
        .input_as = asin.s,
        .input_sep = ", ",

        .output_fix = .round,
        .output_as = asin.b,
        .output_sep = "-",
    };

    const actual = try ArrConfig.parse(input);
    // std.debug.print("{f}\n", .{actual});
    try isEqualArrConfig(expected, actual);
}

fn isEqualArrConfig(config1: ArrConfig, config2: ArrConfig) !void {
    try std.testing.expectEqual(config1.input_fix, config2.input_fix);
    try std.testing.expectEqual(config1.input_as, config2.input_as);
    try std.testing.expectEqualSlices(u8, config1.input_sep, config2.input_sep);

    try std.testing.expectEqual(config1.output_fix, config2.output_fix);
    try std.testing.expectEqual(config1.output_as, config2.output_as);
    try std.testing.expectEqualSlices(u8, config1.output_sep, config2.output_sep);
}
