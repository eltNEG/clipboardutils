const std = @import("std");
const cbu = @import("cbu");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const fields = comptime std.meta.declarations(Operators);
    inline for (fields) |field| {
        if (args.len > 1 and std.mem.eql(u8, field.name, args[1])) {
            _ = try cbu.execClipboardValue(allocator, @field(Operators, field.name));
            return;
        }
    } else {
        _ = try cbu.execClipboardValue(allocator, Operators.print);
    }
}

const Operators = struct {
    pub fn print(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        _ = allocator;
        std.debug.print("Clipboard value: {s}\n", .{data});
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
        std.debug.print("length: {d}\n", .{data.len});
        return null;
    }

    pub fn reverse(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        const output = try allocator.alloc(u8, data.len);
        std.mem.reverse(u8, output);
        return output;
    }

    const Quote = enum { Open, Close };

    /// Remove whitespace and newline from the clipboard value
    pub fn compact(allocator: std.mem.Allocator, data: []const u8) anyerror!?[]u8 {
        const output = try allocator.alloc(u8, data.len);
        var j: usize = 0;
        var quote_state: Quote = .Close;
        var eat_next = false;
        for (data) |c| {
            if (eat_next) {
                output[j] = c;
                j += 1;
                eat_next = false;
                continue;
            }
            switch (c) {
                '"' => {
                    quote_state = if (quote_state == .Open) .Close else .Open;
                    output[j] = c;
                    j += 1;
                },
                '\\' => {
                    if (quote_state == .Open) {
                        eat_next = true;
                    }
                    output[j] = c;
                    j += 1;
                },
                ' ', '\n' => {
                    if (quote_state == .Open) {
                        output[j] = c;
                        j += 1;
                    }
                },
                else => {
                    output[j] = c;
                    j += 1;
                },
            }
        }
        _ = allocator.resize(output, j);

        return output[0..j];
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
