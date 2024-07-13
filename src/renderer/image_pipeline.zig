const std = @import("std");

const zm = @import("zmath");
const vk = @import("vulkan");
const zigimg = @import("zigimg");

const common = @import("../common/common.zig");
const logger = common.logger;
const renderer = @import("renderer.zig");

const software_ray_tracer = @import("../ray_tracing_in_a_weekend/software_ray_tracer.zig");
const path_tracer_app = @import("../path_tracer_app.zig");

const Dimensions = struct {
    width: u32,
    height: u32,
};

const DimensionsBuffer = struct {
    dimensions: Dimensions,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    data_ptr: *Dimensions = undefined,

    pub fn create_dimenson_buffer(instance: *const renderer.Instance, logical_device: *const renderer.logical_device.LogicalDevice, extent: vk.Extent2D) !DimensionsBuffer
    {
        const create_info = vk.BufferCreateInfo 
        {
            .flags = .{},
            .size = @sizeOf(Dimensions),
            .usage = .{ .uniform_buffer_bit = true },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };
        
        const buffer = try logical_device.vk_device.createBuffer(&create_info, null);    
        
        const mem_reqs = logical_device.vk_device.getBufferMemoryRequirements(buffer);

        const allocate_info = vk.MemoryAllocateInfo 
        {
            .allocation_size = mem_reqs.size,
            .memory_type_index = try ImagePipeline.find_memory_type(instance, logical_device.physical_device.vk_physical_device, mem_reqs.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        const memory = try logical_device.vk_device.allocateMemory(&allocate_info, null);
        
        try logical_device.vk_device.bindBufferMemory(buffer, memory, 0);

        const data = try logical_device.vk_device.mapMemory(memory, 0, vk.WHOLE_SIZE, .{});        
        const unaligned_address = @intFromPtr(data.?);
        const alignment = logical_device.physical_device.properties.limits.min_storage_buffer_offset_alignment;
        const aligned_address = (unaligned_address + alignment - 1) & ~(alignment - 1);
        var data_ptr: *Dimensions = @ptrFromInt(aligned_address);

        const dimensions = Dimensions
        {
            .width = extent.width,
            .height = extent.height,
        };

        data_ptr.height = dimensions.height;
        data_ptr.width = dimensions.width;

        return DimensionsBuffer
        {
            .dimensions = dimensions,
            .buffer = buffer,
            .memory = memory,
            .data_ptr = data_ptr,
        };
    }
};

const PixelBuffer = struct 
{  
    src_buffer: vk.Buffer,
    src_memory: vk.DeviceMemory,    
    src_data_ptr: [*]zm.Vec,
    dst_buffer: vk.Buffer = .null_handle,
    dst_memory: vk.DeviceMemory = .null_handle,

    pub fn fill_src_buffer(self: *PixelBuffer, frame: software_ray_tracer.Image) void
    {
        const colours = frame.pixels.items;

        for (0..frame.pixels.items.len) |i| 
        {
            self.src_data_ptr[i] = colours[i];       
        }
    }

    pub fn copy_to_dst(self: *PixelBuffer, vk_device: *const renderer.Device, extent: vk.Extent2D, command_buffer: vk.CommandBuffer) !void 
    {
        const region = vk.BufferCopy2
        {
            .src_offset = 0,
            .dst_offset = 0,
            .size = @sizeOf(zm.Vec) * (extent.width * extent.height),
        };

        const copy_info = vk.CopyBufferInfo2 
        {
            .src_buffer = self.src_buffer,
            .dst_buffer = self.dst_buffer,
            .region_count = 1,
            .p_regions = @ptrCast(&region),        
        };

        vk_device.cmdCopyBuffer2(command_buffer, &copy_info);
    }

    pub fn create_pixel_buffer(instance: *const renderer.Instance, logical_device: *const renderer.logical_device.LogicalDevice, extent: vk.Extent2D) !PixelBuffer    
    {
        const create_info = vk.BufferCreateInfo 
        {
            .flags = .{},
            .size = @sizeOf(zm.Vec) * (extent.width * extent.height),
            .usage = .{ .transfer_src_bit = true },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };
        
        const src_buffer = try logical_device.vk_device.createBuffer(&create_info, null);    
        
        const mem_reqs = logical_device.vk_device.getBufferMemoryRequirements(src_buffer);

        const allocate_info = vk.MemoryAllocateInfo 
        {
            .allocation_size = mem_reqs.size,
            .memory_type_index = try ImagePipeline.find_memory_type(instance, logical_device.physical_device.vk_physical_device, mem_reqs.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        const src_memory = try logical_device.vk_device.allocateMemory(&allocate_info, null);
        
        try logical_device.vk_device.bindBufferMemory(src_buffer, src_memory, 0);

        const data = try logical_device.vk_device.mapMemory(src_memory, 0, vk.WHOLE_SIZE, .{});        
        const unaligned_address = @intFromPtr(data.?);
        const alignment = logical_device.physical_device.properties.limits.min_storage_buffer_offset_alignment;
        const aligned_address = (unaligned_address + alignment - 1) & ~(alignment - 1);
        const src_data_ptr: [*]zm.Vec = @ptrFromInt(aligned_address);

        const dst_create_info = vk.BufferCreateInfo 
        {
            .flags = .{},
            .size = @sizeOf(zm.Vec) * (extent.width * extent.height),
            .usage = .{ .transfer_dst_bit = true, .storage_buffer_bit = true },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };
        
        const dst_buffer = try logical_device.vk_device.createBuffer(&dst_create_info, null);  
        const dst_mem_reqs = logical_device.vk_device.getBufferMemoryRequirements(dst_buffer);

        const dst_allocate_info = vk.MemoryAllocateInfo 
        {
            .allocation_size = dst_mem_reqs.size,
            .memory_type_index = try ImagePipeline.find_memory_type(instance, logical_device.physical_device.vk_physical_device, dst_mem_reqs.memory_type_bits, .{ .device_local_bit = true }),
        };

        const dst_memory = try logical_device.vk_device.allocateMemory(&dst_allocate_info, null);
        try logical_device.vk_device.bindBufferMemory(dst_buffer, dst_memory, 0);

        return PixelBuffer
        {
            .src_buffer = src_buffer,
            .src_memory = src_memory,
            .src_data_ptr = src_data_ptr,
            .dst_buffer = dst_buffer,
            .dst_memory = dst_memory,
        };
    }
};


pub const ImagePipeline = struct 
{
    pipeline_layout: vk.PipelineLayout,
    vk_pipeline: vk.Pipeline,
    command_pool: vk.CommandPool,
    command_buffers: []vk.CommandBuffer,
    image_available_semaphore: vk.Semaphore,
    render_finished_semaphore: vk.Semaphore,
    in_flight_fence: vk.Fence,
    descriptor_sets: [1]vk.DescriptorSet,
    descriptor_set_layouts: [1]vk.DescriptorSetLayout,
    descriptor_pool: vk.DescriptorPool,
    pixel_buffer: PixelBuffer,
    dimensions_buffer: DimensionsBuffer,

    pub fn create_pipeline (
        allocator: *const std.mem.Allocator, 
        ctx: *const renderer.renderer_context.RendererContext, 
        logical_device: *const renderer.logical_device.LogicalDevice,
        render_target: *const renderer.render_target.RenderTarget, 
        render_pass: *const renderer.render_pass.RenderPass) !ImagePipeline 
    {
        const vert_shader_code align(4) = @embedFile("../shaders/pathtrace-vert.spv").*;
        const vert_shader_module: vk.ShaderModule = renderer.create_shader_module(&logical_device.vk_device, &vert_shader_code);
        defer logical_device.vk_device.destroyShaderModule(vert_shader_module, null);

        const frag_shader_code align(4) = @embedFile("../shaders/pathtrace-frag.spv").*;
        const frag_shader_module: vk.ShaderModule = renderer.create_shader_module(&logical_device.vk_device, &frag_shader_code);
        defer logical_device.vk_device.destroyShaderModule(frag_shader_module, null);

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .flags = .{},
                .stage = .{ .vertex_bit = true },
                .module = vert_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .flags = .{},
                .stage = .{ .fragment_bit = true },
                .module = frag_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };

        const vertex_input_info = vk.PipelineVertexInputStateCreateInfo{
            .flags = .{},
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = undefined,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = undefined,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = undefined,
            .scissor_count = 1,
            .p_scissors = undefined,
        };

        const rasterizer = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
            .line_width = 1,
        };

        const multisampling = vk.PipelineMultisampleStateCreateInfo{
            .flags = .{},
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const color_blend_attachment = [_]vk.PipelineColorBlendAttachmentState{.{
            .blend_enable = vk.FALSE,
            .src_color_blend_factor = .one,
            .dst_color_blend_factor = .zero,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        }};

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = color_blend_attachment.len,
            .p_attachments = &color_blend_attachment,
            .blend_constants = [_]f32{ 0, 0, 0, 0 },
        };
        const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };

        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        const command_pool = try logical_device.vk_device.createCommandPool(&.{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = logical_device.graphics_queue.index,
        }, null);

        const command_buffers: []vk.CommandBuffer = try allocator.alloc(vk.CommandBuffer, 1);        
        try logical_device.vk_device.allocateCommandBuffers(&.{
            .command_pool = command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        }, command_buffers.ptr);

        const pixel_buffer = try PixelBuffer.create_pixel_buffer(&ctx.instance, logical_device, render_target.extent);
        
        const dimensions_buffer = try DimensionsBuffer.create_dimenson_buffer(&ctx.instance, logical_device, render_target.extent);

        // var image = try zigimg.Image.fromFilePath(allocator.*, "src/images/vulkano.png");
        // defer image.deinit();        
        //try image.convert(zigimg.ColourFormat.rgba32);
        //var color_it = image.iterator();
        //var index: u32 = 0;
        //var image_colours: []software_ray_tracer.Colour = try allocator.alloc(software_ray_tracer.Colour, 800 * 600);
        //defer allocator.free(image_colours);   
        // while (color_it.next()) |color|
        // {
        //     const colour = software_ray_tracer.Colour{ .r = color.r, .g = color.g, .b = color.b };
        //     _ = colour; // autofix
        //     image_colours[index] = software_ray_tracer.Colour;

        //     index += 1;
        // }
        // for (0..(800*600)) |i|
        // {
        //     gpu_colour_ptr[i] = image_colours[i];
        // }

        //try copy_buffer(logical_device, command_pool, colour_staging_buffer, colour_destination_buffer, @sizeOf(software_ray_tracer.Colour) * (800 * 600));

        const descriptor_set_layout_bindings = [_]vk.DescriptorSetLayoutBinding 
        {
            .{
                .binding = 0,
                .descriptor_type = vk.DescriptorType.storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .fragment_bit = true }, // Assuming the buffer is used in the fragment shader; adjust as necessary.
                .p_immutable_samplers = null
            },
            .{
                .binding = 1,
                .descriptor_type = vk.DescriptorType.uniform_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .fragment_bit = true }, // Assuming the buffer is used in the fragment shader; adjust as necessary.
                .p_immutable_samplers = null
            },
        };

        const create_desp_layout_info = vk.DescriptorSetLayoutCreateInfo 
        { 
            .binding_count = descriptor_set_layout_bindings.len, 
            .p_bindings = &descriptor_set_layout_bindings, 
        };

        const descriptor_set_layouts = [_]vk.DescriptorSetLayout {
            try logical_device.vk_device.createDescriptorSetLayout(&create_desp_layout_info, null)
        };

        const buffer_infos = [_]vk.DescriptorBufferInfo
        {
            .{
                .buffer = pixel_buffer.dst_buffer,
                .offset = 0,
                .range = vk.WHOLE_SIZE,
            },
            .{
                .buffer = dimensions_buffer.buffer,
                .offset = 0,
                .range = vk.WHOLE_SIZE,
            }
        };

        const pool_sizes = [_]vk.DescriptorPoolSize{
            .{ 
                .type = vk.DescriptorType.storage_buffer,
                .descriptor_count = 1,
            },
            .{ 
                .type = vk.DescriptorType.uniform_buffer,
                .descriptor_count = 1,
            },
        };

        const pool_create_info = vk.DescriptorPoolCreateInfo {
            .flags = .{ .free_descriptor_set_bit = true }, 
            .max_sets = 1,
            .pool_size_count = pool_sizes.len,
            .p_pool_sizes = &pool_sizes,
        };

        const descriptor_pool = try logical_device.vk_device.createDescriptorPool(&pool_create_info, null);

        const alloc_info = vk.DescriptorSetAllocateInfo {
            .descriptor_pool = descriptor_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = &descriptor_set_layouts,
        };

        var descriptor_sets: [1]vk.DescriptorSet = undefined;
        try logical_device.vk_device.allocateDescriptorSets(&alloc_info, &descriptor_sets);

        const write_descriptor_sets = [_]vk.WriteDescriptorSet {
            .{ 
                .dst_set = descriptor_sets[0],
                .dst_binding = 0,
                .descriptor_count = 1,
                .descriptor_type = vk.DescriptorType.storage_buffer,
                .dst_array_element = 0,
                .p_image_info = undefined,
                .p_texel_buffer_view = undefined,
                .p_buffer_info = @ptrCast(&buffer_infos[0]),            
            },
            .{
                .dst_set = descriptor_sets[0],
                .dst_binding = 1,
                .descriptor_count = 1,
                .descriptor_type = vk.DescriptorType.uniform_buffer,
                .dst_array_element = 0,
                .p_image_info = undefined,
                .p_texel_buffer_view = undefined,
                .p_buffer_info = @ptrCast(&buffer_infos[1]),            
            }
        };

        logical_device.vk_device.updateDescriptorSets(2, &write_descriptor_sets, 0, null);

        const pipeline_layout = try logical_device.vk_device.createPipelineLayout(&.{
            .flags = .{},
            .set_layout_count = 1,
            .p_set_layouts = &descriptor_set_layouts,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        }, null);

        const pipeline_info = [_]vk.GraphicsPipelineCreateInfo{.{
            .flags = .{},
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_info,
            .p_input_assembly_state = &input_assembly,
            .p_tessellation_state = null,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterizer,
            .p_multisample_state = &multisampling,
            .p_depth_stencil_state = null,
            .p_color_blend_state = &color_blending,
            .p_dynamic_state = &dynamic_state,
            .layout = pipeline_layout,
            .render_pass = render_pass.vk_render_pass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        }};

        const pipelines: []vk.Pipeline = try allocator.alloc(vk.Pipeline, pipeline_info.len);
        defer allocator.free(pipelines);
        _ = try logical_device.vk_device.createGraphicsPipelines(.null_handle, pipeline_info.len, &pipeline_info, null, pipelines.ptr);

        return ImagePipeline
        { 
            .pipeline_layout = pipeline_layout, 
            .vk_pipeline = pipelines[0], 
            .command_pool = command_pool, 
            .command_buffers = command_buffers, 
            .image_available_semaphore = try logical_device.vk_device.createSemaphore(&.{ .flags = .{} }, null), 
            .render_finished_semaphore = try logical_device.vk_device.createSemaphore(&.{ .flags = .{} }, null), 
            .in_flight_fence = try logical_device.vk_device.createFence(&.{ .flags = .{ .signaled_bit = true } }, null) ,
            .descriptor_sets = descriptor_sets,
            .descriptor_set_layouts = descriptor_set_layouts,
            .descriptor_pool = descriptor_pool,
            .pixel_buffer = pixel_buffer,
            .dimensions_buffer = dimensions_buffer,
        };
    }

    fn find_memory_type(instance: *const renderer.Instance, physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) !u32 {
        var mem_properties: vk.PhysicalDeviceMemoryProperties = instance.getPhysicalDeviceMemoryProperties(physical_device);

        for (mem_properties.memory_types[0..mem_properties.memory_type_count], 0..) |mem_type, i| {
            if ((type_filter & (@as(u32, 1) << @truncate(i))) != 0 and (vk.FlagsMixin(vk.MemoryPropertyFlags).contains(mem_type.property_flags, properties))) {
                return @intCast(i);
            }
        }

        return error.NoSuitableMemoryTypeFound;
    }

    pub fn record_commandbuffer(
        self: *ImagePipeline, 
        logical_device: *renderer.logical_device.LogicalDevice, 
        render_target: *renderer.render_target.RenderTarget, 
        render_pass: *renderer.render_pass.RenderPass, 
        frame: software_ray_tracer.Image, 
        frame_count: u32,
        image_index: u32) !void 
    {   
        _ = frame_count; // autofix
        try logical_device.vk_device.beginCommandBuffer(self.command_buffers[0], &.{
            .flags = .{},
            .p_inheritance_info = null,
        });

        self.pixel_buffer.fill_src_buffer(frame);
        try self.pixel_buffer.copy_to_dst(&logical_device.vk_device, render_target.extent, self.command_buffers[0]);

        logical_device.vk_device.cmdBindDescriptorSets(self.command_buffers[0], 
            vk.PipelineBindPoint.graphics, 
            self.pipeline_layout,
            0, // First set
            1, 
            &self.descriptor_sets, 
            0, 
            null);

        const clear_values = [_]vk.ClearValue{.{
            .color = .{ .float_32 = .{ 0, 0, 1, 1 } },
        }};

        const render_pass_info = vk.RenderPassBeginInfo{
            .render_pass = render_pass.vk_render_pass,
            .framebuffer = render_pass.framebuffers[image_index],
            .render_area = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = render_target.extent,
            },
            .clear_value_count = clear_values.len,
            .p_clear_values = &clear_values,
        };

        logical_device.vk_device.cmdBeginRenderPass(self.command_buffers[0], &render_pass_info, .@"inline");
        {
            logical_device.vk_device.cmdBindPipeline(self.command_buffers[0], .graphics, self.vk_pipeline);

            const viewports = [_]vk.Viewport{.{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(render_target.extent.width),
                .height = @floatFromInt(render_target.extent.height),
                .min_depth = 0,
                .max_depth = 1,
            }};
            logical_device.vk_device.cmdSetViewport(self.command_buffers[0], 0, viewports.len, &viewports);

            const scissors = [_]vk.Rect2D{.{
                .offset = .{ .x = 0, .y = 0 },
                .extent = render_target.extent,
            }};
            logical_device.vk_device.cmdSetScissor(self.command_buffers[0] , 0, scissors.len, &scissors);

            logical_device.vk_device.cmdDraw(self.command_buffers[0], 3, 1, 0, 0);
        }
        logical_device.vk_device.cmdEndRenderPass(self.command_buffers[0]);

        try logical_device.vk_device.endCommandBuffer(self.command_buffers[0]);
    }

    pub fn array_to_bytes(allocator: *const std.mem.Allocator, arr: *const []zm.Vec, colour_count: u32) ![]u8 
    {
        const colour_size = @sizeOf(software_ray_tracer.zm.Vec);
        const bytes_size = arr.len * colour_size;        
        const bytes = try allocator.alloc(u8, bytes_size);

        for (arr.ptr, 0..colour_count) |colour, i| 
        {
            const colour_bytes= std.mem.toBytes(&colour);
            const index = i * colour_size;
            for (colour_bytes, 0..) |byte, j| 
            {
                bytes[index + j] = byte;
            }
        }

        return bytes;
    }

    pub fn deinit(self: *ImagePipeline, allocator: *const std.mem.Allocator, vk_device: *renderer.Device) void 
    {
        vk_device.destroyDescriptorSetLayout(self.descriptor_set_layouts[0], null);
        vk_device.destroyDescriptorPool(self.descriptor_pool, null);
        
        vk_device.destroySemaphore(self.render_finished_semaphore, null);
        vk_device.destroySemaphore(self.image_available_semaphore, null);
        vk_device.destroyFence(self.in_flight_fence, null);

        vk_device.destroyBuffer(self.pixel_buffer.src_buffer, null);
        vk_device.freeMemory(self.pixel_buffer.src_memory, null);
        vk_device.destroyBuffer(self.pixel_buffer.dst_buffer, null);
        vk_device.freeMemory(self.pixel_buffer.dst_memory, null);

        vk_device.destroyBuffer(self.dimensions_buffer.buffer, null);
        vk_device.freeMemory(self.dimensions_buffer.memory, null);

        allocator.free(self.command_buffers);

        vk_device.destroyCommandPool(self.command_pool, null);
        vk_device.destroyPipeline(self.vk_pipeline, null);
        vk_device.destroyPipelineLayout(self.pipeline_layout, null);
    }
};