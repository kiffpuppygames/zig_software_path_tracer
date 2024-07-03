const std = @import("std");
const testing = std.testing;

const common = @import("../common/common.zig");
const logger = common.logger;

const cmd_ecs = @import("cmd_ecs.zig");

var world: cmd_ecs.World = undefined;
var test_component_register: TestComponentRegister = undefined;
var command_queue_register: CommandQueueRegister = undefined;
var request_spawn_entity_system: RequestSpawnEntitySystem = undefined;
var spawn_entity_system: SpawnEntitySystem = undefined;
var modify_entity_system: ModifyEntitySystem = undefined;

const TestComponentRegister = struct
{
    test_components: std.AutoArrayHashMap (u64, TestComponent),
    
    fn init(alloc: std.mem.Allocator) TestComponentRegister 
    {
        return TestComponentRegister {
            .test_components = std.AutoArrayHashMap(u64, TestComponent).init(alloc)
        };
    }
};

const CommandQueueRegister = struct
{
    spawn_entity_queue: std.ArrayList(CmdSpawnTestEntity),
    modify_entity_queue: std.ArrayList(CmdModifyTestEntity),
    destroy_entity_queue: std.ArrayList(CmdDestroyTestEntity),
    exit_queue: std.ArrayList(CmdExit),

    fn init(alloc: std.mem.Allocator) CommandQueueRegister 
    {
        return CommandQueueRegister 
        {
            .spawn_entity_queue = std.ArrayList(CmdSpawnTestEntity).init(alloc),
            .modify_entity_queue = std.ArrayList(CmdModifyTestEntity).init(alloc),
            .destroy_entity_queue = std.ArrayList(CmdDestroyTestEntity).init(alloc),
            .exit_queue = std.ArrayList(CmdExit).init(alloc)
        };
    }
};

test "CmdECS workflow: cmd -> create-entity -> cmd -> handle-component -> cmd ->  destroy-entity -> cmd -> exit" 
{
    // logger.info("Running ECS test", .{});

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // world = cmd_ecs.World.init(arena.allocator());
    // test_component_register = TestComponentRegister.init(arena.allocator());
    // command_queue_register = CommandQueueRegister.init(arena.allocator());

    // request_spawn_entity_system = RequestSpawnEntitySystem { 
    //     .spawn_timer = undefined, 
    //     .started = false,
    //     .spawn_delay = 10 * std.time.ns_per_s, 
    //     .spawn_entities = true 
    // };

    // spawn_entity_system = SpawnEntitySystem{ .allocator = arena.allocator()};
    // modify_entity_system = ModifyEntitySystem{};

    // world.set_schedule(run_shedule);

    // logger.info("World Start", .{});
    // world.run();
    // logger.info("World Exit", .{});

    // arena.deinit();
}

pub fn run_shedule() void
{
    request_spawn_entity_system.run();
    spawn_entity_system.run();    
    modify_entity_system.run();
}

const TestComponent = struct
{
    id: u64,
    counter: i32     
};

const RequestSpawnEntitySystem = struct
{
    spawn_timer: std.time.Timer,
    started: bool,
    spawn_delay: u64,
    spawn_entities: bool,

    pub fn run(self: *RequestSpawnEntitySystem) void
    {
        if (self.spawn_entities)
        {
            if (!self.started)
            {   
                logger.info("Spawn Timer Started", .{});
                self.spawn_timer = std.time.Timer.start() catch unreachable;  
                self.started = true;      
            }
            else    
            {
                if (self.spawn_timer.read() >= self.spawn_delay)
                {
                    logger.info("Requesting entity spawn", .{});
                    command_queue_register.spawn_entity_queue.append(CmdSpawnTestEntity{ .id = 0 }) catch unreachable;
                    self.spawn_timer.reset();
                    self.started = false;
                    self.spawn_entities = false;
                }
            }
        }
    }
};

const SpawnEntitySystem = struct
{
    allocator: std.mem.Allocator,

    pub fn run(self: *SpawnEntitySystem) void 
    {
        for (command_queue_register.spawn_entity_queue.items) |_| 
        {
            logger.info("Spawning entity", .{});
            test_component_register.test_components.put(0, TestComponent{ .id = 0, .counter = 0 }) catch unreachable;
            const test_component: ?*TestComponent = test_component_register.test_components.getPtr(0);
            var comp_map = std.AutoArrayHashMap(u64, *anyopaque).init(self.allocator);
            comp_map.put(test_component.?.id, test_component.?) catch unreachable;
            const entity = cmd_ecs.Entity { .id = @intCast(world.entities.count()), .components = comp_map };
            world.entities.put(entity.id, entity) catch unreachable;
            command_queue_register.modify_entity_queue.append( CmdModifyTestEntity { .id = 0, .entity_id = entity.id }) catch unreachable;
        }

        command_queue_register.spawn_entity_queue.clearRetainingCapacity();
    }
};

const ModifyEntitySystem = struct
{
    pub fn run(self: *ModifyEntitySystem) void 
    {        
        _ = self; // autofix
        for (command_queue_register.modify_entity_queue.items) |cmd| 
        {
            logger.info("Modifying entity", .{});
            const entity = world.entities.get(cmd.entity_id);         
            var test_comp: *TestComponent = @ptrCast(entity.?.components.getPtr(cmd.entity_id));

            if (test_comp.counter >= 10)
            {        
                world.exit();
            }
            else 
            {        
                test_comp.counter += 1;
            }

            test_comp.counter += 1;
            logger.info("Entity Modified", .{});
            
            world.exit();
        }
        command_queue_register.modify_entity_queue.clearRetainingCapacity();
    }
};

pub fn destroy_entity() void 
{
    var component = test_component_register.test_components.getPtr(0);

    if (component.?.counter >= 10)
    {        
        world.exit();
    }
    else 
    {        
        component.?.counter += 1;
    }
}

pub fn exit() void 
{
    var component = test_component_register.test_components.getPtr(0);

    if (component.?.counter >= 10)
    {        
        world.exit();
    }
    else 
    {        
        component.?.counter += 1;
    }
}

const CmdSpawnTestEntity = struct 
{
    id: u64    
};

const CmdModifyTestEntity = struct 
{
    id: u64,    
    entity_id: u64
};

const CmdDestroyTestEntity = struct 
{
    id: u64,   
    entity_id: u64 
};

const CmdExit = struct 
{
    id: u64
};

