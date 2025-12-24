const std = @import("std");
const cbu = @import("cbu");
const zeit = @import("zeit");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const fields = comptime std.meta.declarations(Operators);
    for (args[1..]) |arg| {
        inline for (fields) |field| {
            if (args.len > 1 and arg[0] == '.' and std.mem.eql(u8, field.name, arg[1..])) {
                _ = try cbu.execClipboardValue(allocator, @field(Operators, field.name));
            }
        }
    }
}

const Operators = struct {
    pub fn noop(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        _ = allocator;
        _ = data;
        return null;
    }

    pub fn print(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        _ = allocator;
        std.debug.print("{s}\n", .{data});
        return null;
    }

    pub fn lowercase(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        const output = try allocator.alloc(u8, data.len);
        return std.ascii.lowerString(output, data);
    }

    pub fn uppercase(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        const output = try allocator.alloc(u8, data.len);
        return std.ascii.upperString(output, data);
    }

    pub fn len(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        _ = allocator;
        std.debug.print("{d}\n", .{data.len});
        return null;
    }

    pub fn reverse(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
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
    pub fn compact(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
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

    pub fn fromunix(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        const nanoseconds = try std.fmt.parseInt(i98, data, 10) * std.time.ns_per_s;
        const now = zeit.Instant{ .timestamp = nanoseconds, .timezone = &zeit.utc };
        const buf = try allocator.alloc(u8, 19);
        var writer: std.Io.Writer = .fixed(buf);
        try now.time().strftime(&writer, "%d-%m-%Y %H:%M:%S");

        return buf;
    }

    pub fn unixts(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
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
