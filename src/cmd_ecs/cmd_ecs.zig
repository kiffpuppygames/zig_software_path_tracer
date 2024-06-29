const std = @import("std");

const common = @import("../common/common.zig");

const logger = common.logger;

pub const World = struct 
{
    quit: bool,    
    alloc: std.mem.Allocator,
    entities: std.AutoArrayHashMap(u64, Entity),
    systems: std.ArrayList(*const fn() void),
    update_timer: std.time.Timer,
    delta_time_ns: u64,
    schedule: *const fn() void,

    // Private constructor
    pub fn init(alloc: std.mem.Allocator) World 
    {
        logger.info("Initializing ECS", .{});

        return World {
            .quit = false,
            .alloc = alloc,
            .entities = std.AutoArrayHashMap(u64, Entity).init(alloc),
            .systems = std.ArrayList(*const fn() void).init(alloc),
            .update_timer = undefined,
            .delta_time_ns = 0,
            .schedule = undefined,
        };
    }

    pub fn run(self: *World) void
    {
        var timer = std.time.Timer.start() catch unreachable;
        while(!self.quit)
        {
            self.update();
            self.delta_time_ns = timer.lap();            
        }

        self.entities.deinit();
        self.systems.deinit();
    }

    pub fn exit(self: *World) void
    {
        self.quit = true;
    }

    fn update(self: *World) void 
    {
        self.schedule();
    }

    pub fn register_system(self: *World, system:*const fn() void) void 
    {
        logger.info("Registering system", .{});
        self.systems.append(system) catch unreachable;            
    }

    pub fn set_schedule(self: *World, schedule_runner:*const fn() void) void 
    {
        self.schedule = schedule_runner; 
    }
};

pub const Entity = struct 
{
    id: u64,
    components: std.AutoArrayHashMap(u64, *anyopaque)
};

pub fn say_something() void 
{
    logger.info("Hello from ECS", .{});
}