const std = @import("std");
const cbu = @import("cbu");
const zeit = @import("zeit");
const base58 = @import("base58");
const b58 = base58.Table.BITCOIN;

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

    pub fn arr(allocator: std.mem.Allocator, data: []const u8, config: []const u8) anyerror!?[]u8 {
        const cfg = try ArrConfig.parse(config);
        if (cfg.as == .byt) {
            const mul = 2 + (data.len * (3 + cfg.sep.len));
            const buf = try allocator.alloc(u8, mul);
            defer allocator.free(buf);
            var s = try std.fmt.bufPrint(buf[0..], "{c}", .{@intFromEnum(cfg.fix)});
            var j: usize = s.len;
            for (data, 0..) |b, i| {
                _ = i;
                s = try std.fmt.bufPrint(buf[j..], "{d}{s}", .{ b, cfg.sep });
                j += s.len;
            }
            s = try std.fmt.bufPrint(buf[j - cfg.sep.len ..], "{c}", .{cfg.suf});
            std.debug.print("{s}\n", .{buf[0 .. j + s.len - 1]});
        }
        return null;
    }
};

const asin = enum {
    str,
    byt,
};

const brackets = enum(u8) {
    None = '\x00',
    square = '[',
    curly = '{',
    round = '(',
    angle = '<',

    pub fn close(self: brackets) u8 {
        return switch (self) {
            .square => ']',
            .curly => '}',
            .round => ')',
            .angle => '>',
            .None => '\x00',
        };
    }
};

const ArrConfig = struct {
    sep: []const u8 = ", ",
    fix: brackets = .square,
    suf: u8 = brackets.close(.square),
    as: asin = .str,
    in: asin = .str,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("(.sep='{s}', .fix='{c}', .as='{any}', .in='{any}')", .{
            self.sep,
            @intFromEnum(self.fix),
            self.as,
            self.in,
        });
    }
    pub fn parse(config: []const u8) anyerror!ArrConfig {
        var arrConfig = ArrConfig{};
        var iter = std.mem.splitScalar(u8, config, ',');

        while (iter.next()) |item| {
            if (std.mem.startsWith(u8, item, "sep=")) {
                arrConfig.sep = item[4..];
            } else if (std.mem.startsWith(u8, item, "fix=")) {
                arrConfig.fix = std.enums.fromInt(brackets, item[4]) orelse .None;
                arrConfig.suf = brackets.close(arrConfig.fix);
            } else if (std.mem.startsWith(u8, item, "as=")) {
                if (std.meta.stringToEnum(asin, item[3..])) |v| {
                    arrConfig.as = v;
                }
            } else if (std.mem.startsWith(u8, item, "in=")) {
                if (std.meta.stringToEnum(asin, item[3..])) |v| {
                    arrConfig.in = v;
                }
            }
        }
        return ArrConfig{
            .sep = arrConfig.sep,
            .fix = arrConfig.fix,
            .suf = arrConfig.suf,
            .as = arrConfig.as,
            .in = arrConfig.in,
        };
    }
};

test "compact" {
    const allocator = std.testing.allocator;
    const input = "Hello, World!";
    const expected = [_]u8{ 'H', 'e', 'l', 'l', 'o', ',', 'W', 'o', 'r', 'l', 'd', '!' };
    const actual = try Operators.compact(allocator, input);
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, &expected, actual_value);
    }
}

test "compact with quotes" {
    const allocator = std.testing.allocator;
    const input = "\"Hello, World!\".hi johndoe";
    const expected = [_]u8{ '"', 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', '"', '.', 'h', 'i', 'j', 'o', 'h', 'n', 'd', 'o', 'e' };
    const actual = try Operators.compact(allocator, input);
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, &expected, actual_value);
    }
}

test "compact with escaped quotes" {
    const allocator = std.testing.allocator;
    const input = "\"Hello, World!\".hi johndoe";
    const expected = [_]u8{ '"', 'H', 'e', 'l', 'l', 'o', ',', ' ', 'W', 'o', 'r', 'l', 'd', '!', '"', '.', 'h', 'i', 'j', 'o', 'h', 'n', 'd', 'o', 'e' };
    const actual = try Operators.compact(allocator, input);
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
    const actual = try Operators.compact(allocator, jsn);
    if (actual) |actual_value| {
        defer allocator.free(actual_value);
        try std.testing.expectEqualSlices(u8, expected, actual_value);
    }
}
