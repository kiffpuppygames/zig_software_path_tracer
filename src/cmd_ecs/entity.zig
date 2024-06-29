const std = @import("std");

pub const Entity = struct { id: u64, components: std.AutoArrayHashMap(u64, *anyopaque) };
