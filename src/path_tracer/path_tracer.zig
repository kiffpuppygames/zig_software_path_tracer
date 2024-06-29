const std = @import("std");

const common = @import("../common/common.zig");
const cmd_ecs = @import("../cmd_ecs/cmd_ecs.zig");

const logger = common.logger;

const glfw_systems = @import("glfw_systems.zig");

const UpdateSchedule = @import("update_schedule.zig").UpdateSchedule;

pub const PathTracer = struct {
    
    var _instance: ?PathTracer = null;
    var arena: std.heap.ArenaAllocator = undefined;
    
    world: cmd_ecs.world.World = undefined,
    create_window_system: glfw_systems.CreateWindowSystem = undefined,

    fn init() PathTracer {
        arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        return PathTracer {
            .world = cmd_ecs.world.World.init(arena.allocator()),
            .create_window_system = glfw_systems.CreateWindowSystem {
                .cmd_create_window_queue = std.ArrayList(glfw_systems.CmdCreateWindow).init(arena.allocator())
            }
        };
    }
    
    pub fn instance() *PathTracer {
        if (PathTracer._instance == null) {
            _instance = init();
        }
        return &PathTracer._instance.?;
    }
    

    pub fn run(self: *PathTracer) !void {
        logger.info("Running path tracer", .{});

        self.world = cmd_ecs.world.World.init(arena.allocator());

        self.world.set_start_up_schedule(startup_schedule);
        self.world.set_update_schedule(update_schedule);

        self.world.run();
    }

    pub fn startup_schedule() void {
        logger.info("Running startup schedule", .{});
        glfw_systems.glfw_init();
    }

    pub fn update_schedule() void {
        PathTracer.instance().create_window_system.run();
    }
};


