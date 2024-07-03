const std = @import("std");

const glfw = @import("mach-glfw");

const common = @import("../common/common.zig");
const cmd_ecs = @import("../cmd_ecs/cmd_ecs.zig");

const logger = common.logger;

const window_system = @import("window_system.zig");
const renderer_system = @import("renderer_system.zig");
const image_transfer_pipeline = @import("image_transfer_pipeline.zig");

const WindowComponent = struct {
    id: u64,
    window: glfw.Window,
};

pub const PathTracer = struct {
    var _instance: ?PathTracer = null;
    var arena: std.heap.ArenaAllocator = undefined;

    init_renderer_queue: std.ArrayList(renderer_system.CmdInitRenderer) = std.ArrayList(renderer_system.CmdInitRenderer).init(arena.allocator()),
    world: cmd_ecs.world.World = undefined,
    window_system: window_system.WindowSystem = undefined,
    renderer: renderer_system.Renderer = undefined,
    window_components: std.AutoArrayHashMap(u64, WindowComponent) = undefined,
    arena: *std.heap.ArenaAllocator = undefined,
    id_provider: cmd_ecs.id_provider.IdProvider = cmd_ecs.id_provider.IdProvider.init(),
    render_pass_group: renderer_system.RenderPassGroup = undefined,
    image_transfer_pipeline: image_transfer_pipeline.ImageTransferPipeline = undefined,

    create_image_transfer_pipeline_cmd_q: std.ArrayList(image_transfer_pipeline.CmdCreateImageTransferPipeline),   

    fn init() PathTracer {
        arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        var id_provider = cmd_ecs.id_provider.IdProvider.init();

        return PathTracer{
            .world = cmd_ecs.world.World.init(&arena),
            .window_system = window_system.WindowSystem{ 
                .cmd_create_window_queue = std.ArrayList(window_system.CmdCreateWindow).init(arena.allocator()), 
                .cmd_create_window_component_queue = std.ArrayList(window_system.CmdCreateWindowComponent).init(arena.allocator()), 
                .cmd_exit_app = std.ArrayList(window_system.CmdExitApp).init(arena.allocator()), 
                .id_provider = &id_provider 
            },
            .renderer = undefined,
            .window_components = std.AutoArrayHashMap(u64, WindowComponent).init(arena.allocator()),
            .arena = &arena,
            .id_provider = id_provider,
            .create_image_transfer_pipeline_cmd_q = std.ArrayList(image_transfer_pipeline.CmdCreateImageTransferPipeline).init(arena.allocator()),
            .render_pass_group = undefined,
            .image_transfer_pipeline = undefined,
        };
    }
   
    pub fn instance() *PathTracer {
        if (PathTracer._instance == null) {
            _instance = init();
        }

        return &PathTracer._instance.?;
    }

    pub fn run(self: *PathTracer) !void {
        self.world = cmd_ecs.world.World.init(self.arena);

        self.world.set_start_up_schedule(startup_schedule);
        self.world.set_update_schedule(update_schedule);

        self.world.run();
    }

    fn create_window_component(self: *PathTracer) void {
        for (self.window_system.cmd_create_window_component_queue.items) |value| {
            value.window.setKeyCallback(handle_input_callback);

            const window_component = WindowComponent{ .id = self.id_provider.get_id(), .window = value.window };

            self.window_components.put(window_component.id, window_component) catch unreachable;
        }
        self.window_system.cmd_create_window_component_queue.clearRetainingCapacity();
    }

    pub fn handle_renderer_init_cmds(self: *PathTracer) void 
    {        
        for (self.init_renderer_queue.items) |_| 
        {
            self.renderer = renderer_system.Renderer.init(self.arena);
        }
        self.init_renderer_queue.clearRetainingCapacity();
    }

    pub fn handle_window_events(self: *PathTracer) void {
        for (self.window_components.values()) |value| {
            const window = value.window;
            if (window.shouldClose()) {
                self.shutdown();
            }
            //window.swapBuffers();
            glfw.pollEvents();
        }
    }

    pub fn startup_schedule() void {
        window_system.glfw_init();
        PathTracer.instance().window_system.cmd_create_window_queue.append(window_system.CmdCreateWindow{
            .id = PathTracer.instance().id_provider.get_id(),
            .width = 800,
            .height = 600,
            .title = "Path Tracer",
        }) catch unreachable;
    }

    pub fn update_schedule() void {
        PathTracer.instance().window_system.run();
        PathTracer.instance().create_window_component();
        PathTracer.instance().handle_window_events();
        PathTracer.instance().handle_renderer_init_cmds();
        PathTracer.instance().renderer.handle_create_logical_device_cmds();    
        PathTracer.instance().renderer.handle_create_render_target_cmds();  
        PathTracer.instance().handle_create_image_transfer_pipeline_cmds();
        PathTracer.instance().renderer.draw_frame(PathTracer.instance().image_transfer_pipeline.command_buffer, PathTracer.instance().image_transfer_pipeline.in_flight_fence, PathTracer.instance().image_transfer_pipeline.image_available_semaphore, PathTracer.instance().image_transfer_pipeline.render_finished_semaphore);  
    }

    pub fn handle_input_callback(glfw_window: glfw.Window, key: glfw.Key, scan_code: i32, action: glfw.Action, mods: glfw.Mods) void 
    {
        _ = glfw_window; // autofix
        _ = scan_code; // autofix
        _ = mods; // autofix

        if (action == glfw.Action.press and key == glfw.Key.F1) 
        {
            PathTracer.instance().init_renderer_queue.append(renderer_system.CmdInitRenderer { 
                .id = PathTracer.instance().id_provider.get_id(), 
            }) catch unreachable;    
        }

        if (action == glfw.Action.press and key == glfw.Key.F2) 
        {
            if (PathTracer.instance().renderer.context == null) {
                logger.err("Renderer not initialized", .{});
                return;
            }

            PathTracer.instance().renderer.create_logical_device_cmd_queue.append(renderer_system.CmdCreateLogicalDevice { 
                .id = PathTracer.instance().id_provider.get_id(), 
            }) catch unreachable;    
        }

        if (action == glfw.Action.press and key == glfw.Key.F3) 
        {
            if (PathTracer.instance().renderer.logical_device == null) {
                logger.err("Device not initialized", .{});
                return;
            }

            PathTracer.instance().renderer.create_render_target_cmd_queue.append(renderer_system.CmdCreateRenderTarget { 
                .id = PathTracer.instance().id_provider.get_id(),
                .window = &PathTracer.instance().window_components.values()[0].window,
            }) catch unreachable;
        }

        if (action == glfw.Action.press and key == glfw.Key.F4) 
        {
            if (PathTracer.instance().renderer.render_target == null) {
                logger.err("Render target not initialized", .{});
                return;
            }

            PathTracer.instance().create_image_transfer_pipeline_cmd_q.append(image_transfer_pipeline.CmdCreateImageTransferPipeline { 
                .id = PathTracer.instance().id_provider.get_id(),
            }) catch unreachable;
        }
    }

    pub fn handle_create_image_transfer_pipeline_cmds(self: *PathTracer) void
    {
        for (self.create_image_transfer_pipeline_cmd_q.items) |_| 
        {            
            self.render_pass_group = renderer_system.RenderPassGroup.init(self.arena.allocator(), &self.renderer.logical_device.?.device, self.renderer.render_target.?.format, &self.renderer.render_target.?.image_views);

            self.image_transfer_pipeline = image_transfer_pipeline.ImageTransferPipeline.init(
                self.arena, 
                800, 
                600, 
                &self.renderer.logical_device.?.device, 
                &self.render_pass_group,
                self.renderer.logical_device.?.graphics_queue
            );
            logger.debug("Image Transfer Pipeline Created", .{});
        }
        self.create_image_transfer_pipeline_cmd_q.clearRetainingCapacity();    
    }

    fn shutdown(self: *PathTracer) void {
        self.window_system.cmd_exit_app.deinit();

        for (self.window_components.values()) |value| {
            value.window.destroy();
        }

        for (self.render_pass_group.framebuffers.items) |framebuffer| {
            self.renderer.logical_device.?.device.destroyFramebuffer(framebuffer, null);
        }
        self.renderer.logical_device.?.device.destroyRenderPass(self.render_pass_group.render_pass, null);
        self.renderer.logical_device.?.device.destroyPipelineLayout(self.image_transfer_pipeline.pipeline_layout, null);
        self.renderer.logical_device.?.device.destroyPipeline(self.image_transfer_pipeline.graphics_pipeline, null);
        self.renderer.logical_device.?.device.destroyCommandPool(self.image_transfer_pipeline.command_pool, null);

        self.renderer.shutdown();

        self.window_components.deinit();
        self.window_system.shutdown();

        self.world.shutdown();

        self.arena.deinit();
        std.process.exit(0);
    }
};
