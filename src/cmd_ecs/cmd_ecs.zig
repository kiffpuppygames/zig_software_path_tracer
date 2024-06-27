const std = @import("std");

const common = @import("../common/common.zig");

const logger = common.logger;

const System = *const fn() void;

pub const World = struct 
{    
    var instance: ?World = null;
    var quit: bool = false;
    var arena: std.heap.ArenaAllocator = undefined;

    entities: std.ArrayList(Entity),
    systems: std.ArrayList(System),
    component_register: std.StringArrayHashMap(std.AutoArrayHashMap(u64, type)),

    // Private constructor
    fn init() void 
    {
        var new_arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        instance = World {
            .entities = std.ArrayList(Entity).init(new_arena.allocator()),
            .systems = std.ArrayList(System).init(new_arena.allocator()),
            .component_register = std.StringArrayHashMap(std.AutoArrayHashMap( u64, type)).init(new_arena.allocator())
        };
        World.arena = new_arena;
    }

    // Public accessor function
    pub fn get_instance() *World 
    {
        if (instance == null) 
        {
            World.init();
        }
        return &instance.?;
    }

    pub fn run(self: *World) void
    {
        while(!quit)
        {
            instance.?.update();
        }

        logger.info("Cleaning up", {});

        self.entities.deinit();
        self.systems.deinit();
        self.component_register.deinit();

        logger.info("World has exited", {});

        self.arena.deinit();
    }

    pub fn exit() void
    {
        quit = true;
    }

    fn update(self: *World) void 
    {
        for (self.systems.items) |system| 
        {
            system();
        }
    }

    pub fn add_component(self: *World, component: anytype) void 
    { 
        if (!@hasField(@TypeOf(component), "id")) 
        {
            @compileError("add_component: Component type must have an 'id' field");
        }

        var component_map = self.component_register.get(@typeName(component));
        component_map.append(component.id, component) catch unreachable;
    }

    pub fn get_component(self: *World, id: u64, T: type) T 
    {
        return self.component_register.get(@typeName(T)).?.get(id).?;
    }

    pub fn register_system(self: *World, system:System) void 
    {
        self.systems.append(system) catch unreachable;            
    }

    pub fn register_component(self: *World, component_type: type) void 
    {
        if (!@hasField(component_type, "id")) 
        {
            @compileError("register_component: Component type must have an 'id' field");
        }

        self.component_register.put(@typeName(component_type), std.ArrayList(type).init(World.arena.allocator())) catch unreachable;
    }
};

pub const Entity = struct 
{
    id: u32,
    components: std.AutoArrayHashMap(u64, type),
};

pub fn say_something() void 
{
    logger.info("Hello from ECS", .{});
}