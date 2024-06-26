const std = @import("std");

pub inline fn padString(allocator: std.mem.Allocator, str: []u8, pad_amount: u8, pad_char: *const [1:0]u8) []u8 {
    const chars_to_add: u8 = @intCast(pad_amount - str.len);

    var pad_str = allocator.alloc(u8, chars_to_add) catch unreachable;

    for (0..pad_str.len) |i| {
        pad_str[i] = pad_char[0];
    }

    const final_str = std.fmt.allocPrint(allocator, "{s}{s}", .{ pad_str, str }) catch unreachable;
    return final_str;
}

pub inline fn toNullTerminated(alloc: std.mem.Allocator, str: []const u8) [*:0]const u8 {
    return std.fmt.allocPrintZ(alloc, "{s}", .{str}) catch unreachable;
}