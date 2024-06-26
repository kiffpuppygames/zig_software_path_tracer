const std = @import("std");
const common = @import("../common/common.zig");

const logger = common.logger;

pub const World = struct 
{
    systems: std.StringArrayHashMap(System),

    pub fn add_system(self: *World, system: System) void 
    {
        self.systems.put(system.name, system) catch unreachable;
    }
};

pub const System = struct 
{
    name: []const u8,  

    pub fn update(self: *const System) void 
    {
        logger.info("Hello from System {s}", .{ self.name });
    }       
};

