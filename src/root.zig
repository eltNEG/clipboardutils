//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const clipboard = @import("clipboard");

pub fn execClipboardValue(allocator: std.mem.Allocator, func: *const fn (_allocator: std.mem.Allocator, _data: []const u8) anyerror!?[]u8) !void {
    var clip = try clipboard.Clipboard.init(allocator);
    defer clip.deinit();
    var data = try clip.read(.text);
    defer data.deinit();
    const text = try data.asText();
    const result = try func(allocator, text);
    if (result) |value| {
        defer allocator.free(value);
        try clip.write(value, .text);
    }
    return;
}
