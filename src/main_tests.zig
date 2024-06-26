const std = @import("std");
const testing = std.testing;

const common = @import("common/common.zig");
const log = common.logger;

const cmd_ecs = @import("cmd_ecs/cmd_ecs.zig");

test "Add system and run update method x times" 
{
    const allocator = std.testing.allocator;

    var world = cmd_ecs.World { .systems = std.StringArrayHashMap(cmd_ecs.System).init(allocator)};

    const system = cmd_ecs.System { .name = "Test System"};

    world.add_system(system);

    var i: usize = 0; 
    while (i < 10) 
    {
        for (world.systems.values()) |value|  
        {
            value.update();
        }
        i += 1;
    }

    world.systems.deinit();

    try testing.expect(i == 10);      
}

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