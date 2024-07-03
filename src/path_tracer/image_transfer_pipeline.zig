const std = @import("std");

const vk = @import("vulkan");

const renderer_system = @import("renderer_system.zig");
const shaders = @import("shaders");

const logger = @import("../common/common.zig").logger;

const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const CmdCreateImageTransferPipeline = struct {
    id: u64
};

const Vertex = struct {
    const binding_description = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .input_rate = .vertex,
    };

    const attribute_description = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .binding = 0,
            .location = 1,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Vertex, "color"),
        },
    };

    pos: [2]f32,
    color: [3]f32,
};

const vertices = [_]Vertex{
    .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0, 1, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
};

pub const ImageTransferPipeline = struct 
{
    allocator: *std.heap.ArenaAllocator = undefined,
    cpu_pixels: std.ArrayList(Pixel) = undefined,
    staging_buffer: vk.Buffer = undefined,
    staging_buffer_memory: vk.DeviceMemory = undefined,
    render_pass: vk.RenderPass = undefined,
    pipeline_layout: vk.PipelineLayout = undefined,
    graphics_pipeline: vk.Pipeline = undefined,
    command_pool: vk.CommandPool = undefined,
    command_buffer: vk.CommandBuffer = undefined,
    image_available_semaphore: vk.Semaphore = .null_handle,
    render_finished_semaphore: vk.Semaphore = .null_handle,
    in_flight_fence: vk.Fence = .null_handle,

    pub fn init(alloc: *std.heap.ArenaAllocator, width: u32, height: u32, device: *renderer_system.Device, render_pass_group: *renderer_system.RenderPassGroup, graphics_queue: u32) ImageTransferPipeline 
    {
        const pixels = std.ArrayList(Pixel).initCapacity(alloc.allocator(), width * height) catch unreachable;

        const vert_shader_code align(4) = @embedFile("../shaders/vert.spv").*;
        const vert_shader_mod = create_shader_module(&vert_shader_code, device);
        defer device.destroyShaderModule(vert_shader_mod, null);

        const frag_shader_code align(4) = @embedFile("../shaders/frag.spv").*;
        const frag_shader_mod = create_shader_module(&frag_shader_code, device);
        defer device.destroyShaderModule(frag_shader_mod, null);
        
        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .flags = .{},
                .stage = .{ .vertex_bit = true },
                .module = vert_shader_mod,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .flags = .{},
                .stage = .{ .fragment_bit = true },
                .module = frag_shader_mod,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };   

        const dynamic_states = [_]vk.DynamicState{
            .viewport,
            .scissor,
        };
        const dynamic_state_ceate_info = vk.PipelineDynamicStateCreateInfo {
            .dynamic_state_count = 2,
            .p_dynamic_states = &dynamic_states,
        };

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo {
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = null,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = null,
        };
                
        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo {
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport = vk.Viewport {
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        };
        const viewports = [1]vk.Viewport{ viewport };

        const scissor = vk.Rect2D {
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = @intCast(width), .height = @intCast(height) },
        };
        const scissors = [1]vk.Rect2D{ scissor };

        const viewport_state = vk.PipelineViewportStateCreateInfo {
            .viewport_count = 1,
            .p_viewports = &viewports,
            .scissor_count = 1,
            .p_scissors = &scissors,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo {
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .line_width = 1.0,
            .cull_mode = .{ .back_bit = true },
            .front_face = .counter_clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo {
            .sample_shading_enable = vk.FALSE,
            .rasterization_samples = .{ .@"1_bit" = true },
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const color_blend_attachment = vk.PipelineColorBlendAttachmentState {
            .blend_enable = vk.FALSE,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        };
        const colour_blend_attachments = [1]vk.PipelineColorBlendAttachmentState{ color_blend_attachment }; 

        const color_blending = vk.PipelineColorBlendStateCreateInfo {
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = &colour_blend_attachments,
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };
        
        const pipeline_layout_info = vk.PipelineLayoutCreateInfo {
            .set_layout_count = 0,
            .p_set_layouts = null,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = null,
        };

        const pipeline_layout = device.createPipelineLayout(&pipeline_layout_info, null) catch unreachable;

        const pipeline_info = vk.GraphicsPipelineCreateInfo {
            .stage_count = 2,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &input_assembly,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = null,
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state_ceate_info,
            .layout = pipeline_layout,
            .render_pass = render_pass_group.render_pass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };
        const pipeline_create_infos = [1]vk.GraphicsPipelineCreateInfo { pipeline_info };

        const pipeline : vk.Pipeline = undefined;
        var pipelines = [1]vk.Pipeline{ pipeline };
        _ = device.createGraphicsPipelines(vk.PipelineCache.null_handle, 1, &pipeline_create_infos, null, &pipelines) catch unreachable;

        const command_pool_create_info = vk.CommandPoolCreateInfo {
            .queue_family_index = graphics_queue,
            .flags = .{},
        };

        const command_pool = device.createCommandPool(&command_pool_create_info, null) catch unreachable;

        const command_buffer_allocate_info = vk.CommandBufferAllocateInfo {
            .command_pool = command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        const command_buffer : vk.CommandBuffer = undefined;
        var command_buffers = [_]vk.CommandBuffer{ command_buffer };
        _ = device.allocateCommandBuffers(&command_buffer_allocate_info, &command_buffers) catch unreachable;  

        record_command_buffer(command_buffers[0], device, render_pass_group, width, height, pipelines[0]);

        const image_available_semaphore = device.createSemaphore( &.{ .flags = .{} }, null) catch unreachable;
        const render_finished_semaphore = device.createSemaphore( &.{ .flags = .{} }, null) catch unreachable;
        const in_flight_fence = device.createFence( &.{ .flags = .{ .signaled_bit = true } }, null) catch unreachable;

        return ImageTransferPipeline{
            .allocator = alloc,
            .cpu_pixels = pixels,
            .staging_buffer = undefined,
            .staging_buffer_memory = undefined,
            .render_pass = render_pass_group.render_pass,
            .pipeline_layout = pipeline_layout,
            .graphics_pipeline = pipelines[0],
            .command_pool = command_pool,
            .command_buffer = command_buffers[0],
            .image_available_semaphore = image_available_semaphore,
            .render_finished_semaphore = render_finished_semaphore,
            .in_flight_fence = in_flight_fence,
        };
    }

    fn record_command_buffer(command_buffer: vk.CommandBuffer, device: *renderer_system.Device, render_pass_group: *renderer_system.RenderPassGroup, width: u32, height: u32, pipeline: vk.Pipeline) void 
    {        
        const command_buffer_begin_info = vk.CommandBufferBeginInfo {
            .flags = .{},
            .p_inheritance_info = null,
        };

        device.beginCommandBuffer(command_buffer, &command_buffer_begin_info) catch unreachable;

        const render_pass_begin_info = vk.RenderPassBeginInfo {
            .render_pass = render_pass_group.render_pass,
            .framebuffer = render_pass_group.framebuffers.items[0],
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{ .width = @intCast(width), .height = @intCast(height) },
            },
            .clear_value_count = 0,
            .p_clear_values = null,
        };
        
        device.cmdBeginRenderPass(command_buffer, &render_pass_begin_info, .@"inline");

        device.cmdBindPipeline(command_buffer, vk.PipelineBindPoint.graphics, pipeline);

        const viewport = vk.Viewport {
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
            .min_depth = 0.0,
            .max_depth = 1.0,
        };
        const viewports = [1]vk.Viewport{ viewport };
        device.cmdSetViewport(command_buffer, 0, 1, &viewports);

        const scissor = vk.Rect2D {
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = @intCast(width), .height = @intCast(height) },
        };
        const scissors = [1]vk.Rect2D{ scissor };
        device.cmdSetScissor(command_buffer, 0, 1, &scissors);

        device.cmdDraw(command_buffer, 3, 1, 0, 0);

        device.cmdEndRenderPass(command_buffer);

        device.endCommandBuffer(command_buffer) catch unreachable;
    }

    fn create_shader_module(code: []align(@alignOf(u32)) const u8, device: *renderer_system.Device) vk.ShaderModule {
        
        const vert_mod_create_info = vk.ShaderModuleCreateInfo {
            .code_size = code.len,
            .p_code = std.mem.bytesAsSlice(u32, code).ptr,
        };
        const vert_shader_mod: vk.ShaderModule = device.createShaderModule(&vert_mod_create_info, null) catch unreachable;
        return vert_shader_mod;
    }

    // pub fn blit(src: []const u8, dst: []u8, src_width: u32, src_height: u32, dst_width: u32, dst_height: u32) void {
    //     const src_stride = src_width * 4;
    //     const dst_stride = dst_width * 4;

    //     var src_row = src;
    //     var dst_row = dst;

    //     for (src_height) |_, src_row| {
    //         const src_pixel = @intToPtr(*src_row, [*]Pixel);
    //         var dst_pixel = @intToPtr(*dst_row, [*]Pixel);

    //         for (src_width) |_, src_pixel| {
    //             dst_pixel.* = src_pixel.*;

    //             dst_pixel = dst_pixel + 1;
    //             src_pixel = src_pixel + 1;
    //         }

    //         src_row = src_row + src_stride;
    //         dst_row = dst_row + dst_stride;
    //     }
    // }
};