const std = @import("std");
const cbu = @import("cbu");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // if (args.len > 1) {
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
};
