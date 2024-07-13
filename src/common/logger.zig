const std = @import("std");
const date_time = @import("date_time.zig");

const RED = "\x1b[31;1m";
const GREEN = "\x1b[32;1m";
const YELLOW = "\x1b[33;1m";
const BLUE = "\x1b[34;1m";
const MAGENTA = "\x1b[35;1m";
const RESET = "\x1b[0m";

const CYAN = "\x1b[36;1m";
const WHITE = "\x1b[37;1m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";

pub fn write(msg: []const u8) void 
{
    std.debug.print("{s}\n", .{msg});
}

pub fn info(comptime msg: []const u8, args: anytype) void 
{
    const level = std.fmt.comptimePrint("{s}INFO {s}", .{ BLUE, RESET });    
    write_log(level, msg, args);
}

pub fn debug(comptime msg: []const u8, args: anytype) void 
{
    const level = std.fmt.comptimePrint("{s}DEBUG{s}", .{ MAGENTA, RESET });    
    write_log(level, msg, args);
}

pub fn warn(comptime msg: []const u8, args: anytype) void 
{
    const level = std.fmt.comptimePrint("{s}WARN {s}", .{ YELLOW, RESET });
    write_log(level, msg, args);
}

pub fn err(comptime msg: []const u8, args: anytype) void 
{
    const level = std.fmt.comptimePrint("{s}ERROR{s}", .{ RED, RESET });
    write_log(level, msg, args);
}

fn write_log(level: *const [16:0]u8, comptime msg: []const u8, args: anytype) void 
{
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const formatted_msg = std.fmt.allocPrint(arena.allocator(), msg, args) catch |e| 
    {
        std.debug.print("Error writing to stdout: {!}\n", .{e});
        @panic("OOPS");
    };
    const final_msg = std.fmt.allocPrint(arena.allocator(), "[{s}] {s} : {s}", .{ level, date_time.getNowString(arena.allocator()), formatted_msg }) catch |e| 
    {
        std.debug.print("Error writing to stdout: {!}\n", .{e});        
        @panic("OOPS Again");
    };
    
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());

    std.debug.print("{s}\n", .{final_msg});     
    // bw.writer().print("{s}\n", .{final_msg}) catch |e| 
    // {
    //     std.debug.print("Error writing to stdout: {!}\n", .{e});
    // };

    bw.flush() catch unreachable;
}

pub fn log_progress(comptime msg: []const u8, args: anytype) void 
{
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const formatted_msg = std.fmt.allocPrint(arena.allocator(), msg, args) catch |e| 
    {
        std.debug.print("Error writing to stdout: {!}\n", .{e});
        @panic("OOPS");
    };

    const final_msg = std.fmt.allocPrint(arena.allocator(), "\x1b[A\x1b[2K{s}", .{ formatted_msg }) catch |e| 
    {
        std.debug.print("Error writing to stdout: {!}\n", .{e});        
        @panic("OOPS Again");
    };

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());

    // Use std.debug.print or bw.writer().print to write the final message
    bw.writer().print("{s}\n", .{final_msg}) catch |e| 
    {
        std.debug.print("Error writing to stdout: {!}\n", .{e});
    };
}