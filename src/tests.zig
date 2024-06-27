const std = @import("std");
const testing = std.testing;

comptime 
{
    _ = @import("cmd_ecs/tests.zig");
}

const log = @import("common/common.zig").logger;

test "basic add functionality" 
{
    log.write("\n");
    log.info("This is a test {s} message", .{"INFO"});
    std.time.sleep(1000000);
    log.debug("This is a test {s} message", .{"DEBUG"});
    std.time.sleep(1000000);
    log.warn("This is a test {s} message", .{"WARN"});
    std.time.sleep(1000000);
    log.err("This is a test {s} message", .{"ERROR"});

    try testing.expect(true);
}