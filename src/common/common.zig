const std = @import("std");

pub const date_time = @import("date_time.zig");
pub const logger = @import("logger.zig");
pub const string_format = @import("string_format.zig");

// pub fn main() !void
// {
//     logger.info("This is a test {s} message", .{"INFO"});
//     std.time.sleep(1000000);
//     logger.debug("This is a test {s} message", .{"DEBUG"});
//     std.time.sleep(1000000);
//     logger.warn("This is a test {s} message", .{"WARN"});
//     std.time.sleep(1000000);
//     logger.err("This is a test {s} message", .{"ERROR"});
// }