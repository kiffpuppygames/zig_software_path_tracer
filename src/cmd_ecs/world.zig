const std = @import("std");
const common = @import("../common/common.zig");
const logger = common.logger;

const cmd_ecs = @import("cmd_ecs.zig");
const Entity = cmd_ecs.entity.Entity;

pub const World = struct {
    quit: bool,
    alloc: std.mem.Allocator,
    entities: std.AutoArrayHashMap(u64, Entity),
    systems: std.ArrayList(*const fn () void),
    update_timer: std.time.Timer,
    delta_time_ns: u64,
    start_up_schedule: *const fn () void,
    update_schedule: *const fn () void,

    pub fn init(alloc: std.mem.Allocator) World {
        return World{
            .quit = false,
            .alloc = alloc,
            .entities = std.AutoArrayHashMap(u64, Entity).init(alloc),
            .systems = std.ArrayList(*const fn () void).init(alloc),
            .update_timer = undefined,
            .delta_time_ns = 0,
            .start_up_schedule = undefined,
            .update_schedule = undefined,
        };
    }

    pub fn run(self: *World) void {
        var timer = std.time.Timer.start() catch unreachable;

        self.start_up_schedule();

        while (!self.quit) {
            self.update();
            self.delta_time_ns = timer.lap();
        }

        self.entities.deinit();
        self.systems.deinit();
    }

    pub fn exit(self: *World) void {
        self.quit = true;
    }

    fn update(self: *World) void {
        self.update_schedule();
    }

    pub fn set_update_schedule(self: *World, schedule: *const fn () void) void {
        self.update_schedule = schedule;
    }

    pub fn set_start_up_schedule(self: *World, schedule: *const fn () void) void {
        self.start_up_schedule = schedule;
    }
};
