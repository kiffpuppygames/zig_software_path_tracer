const std = @import("std");
const testing = std.testing;

const common = @import("common");
const log = common.logger;

const cmd_ecs = @import("cmd_ecs.zig");

test "Register system and component run it x times exit and cleanup" 
{    
    const world = cmd_ecs.World.get_instance();

    world.register_system(test_system);
    world.register_component(TestComponent);

    world.add_component(TestComponent{ .id = 1, .counter = 0 });

    world.run();
}

pub const TestComponent = struct
{
    id: u32,
    counter: i32        
};

pub fn test_system() void 
{
    var world = cmd_ecs.World.get_instance();

    var component = world.get_component(1, TestComponent);

    if (component.counter >= 10)
    {
        world.exit();
    }
    else 
    {
        component.counter += 1;
    }
}