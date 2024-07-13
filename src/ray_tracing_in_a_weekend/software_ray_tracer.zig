const std = @import("std");

const zm = @import("zmath");

pub const common = @import("../common/common.zig");
pub const logger = common.logger;
pub const data_structs = @import("data_structs.zig");

pub const Dimensions = data_structs.Dimensions;
pub const ViewPort = data_structs.ViewPort;
pub const Image = data_structs.Image;
pub const Ray = data_structs.Ray;
pub const Camera = data_structs.Camera;
pub const Cube = data_structs.Cube;

pub const SoftwarePathTracer = struct 
{
    dimensions: Dimensions,
    camera: Camera,
    cube: Cube,

    pub fn init(width: u32, height: u32, aspect_ratio: f32, near_clip_distance: f32, camera_origin: zm.Vec) SoftwarePathTracer
    {
        const camera_view_direction = zm.Vec { 0, 0, 1, 0};
        const f_width: f32 = @floatFromInt(width);
        const f_height: f32 = @floatFromInt(height);

        const viewport_aspect_ratio: f32 = f_width / f_height;
        const viewport_height: f32 = 2.0;
        const viewport_width = viewport_height * viewport_aspect_ratio;

        const view_port_center = zm.Vec { camera_origin[0], camera_origin[1], camera_origin[2] + near_clip_distance, 1 };
        const viewport_upper_left = zm.Vec { view_port_center[0] + (-viewport_width / 2), view_port_center[1] + (viewport_height / 2), 0, 1 };

        const pixel_size = zm.Vec { viewport_width / f_width, viewport_height / f_height, 0, 1 };
        
        const ray_zero_target_point = zm.Vec { viewport_upper_left[0] + (pixel_size[0] / 2), viewport_upper_left[1] + (pixel_size[1] / 2), near_clip_distance, 1 };
        
        const cube: Cube = Cube.new(zm.Vec {0, 0, 5, 1 }, 1, random_colour(), zm.Vec { 0, 0, 0, 1 }, zm.Vec { 0, 0, 1, 0 });

        const camera = Camera 
        { 
            .origin = camera_origin,
            .view_direction = camera_view_direction,
            .near_clip_distance = near_clip_distance,
            .viewport = ViewPort { 
                .width = viewport_width, 
                .height = viewport_height,
                .viewport_upper_left = viewport_upper_left,
                .pixel_size = pixel_size,
                .ray_zero_target_point = ray_zero_target_point,
            }
        };

        return SoftwarePathTracer 
        { 
            .dimensions = Dimensions { .width = width, .height = height, .aspect_ratio = aspect_ratio },
            .camera = camera,
            .cube = cube,
        };
    }

    pub fn generate_frame(self: *SoftwarePathTracer, allocator: *const std.mem.Allocator) !Image
    {
        var timer = try std.time.Timer.start();

        var pixels = try std.ArrayList(zm.Vec).initCapacity(allocator.*, self.dimensions.width * self.dimensions.height); 

        for (0..self.dimensions.height) |y|
        {
            for(0..self.dimensions.width) |x|
            {
                const view_port_ray_point = get_viewport_ray_point(&self.camera, zm.Vec { @floatFromInt(x), @floatFromInt(y), 0, 1 });

                const ray_direction = zm.normalize4(zm.Vec { view_port_ray_point[0] - self.camera.origin[0], view_port_ray_point[1] - self.camera.origin[1], view_port_ray_point[2] - self.camera.origin[2], 0});
                                
                const ray = Ray 
                { 
                    .origin = self.camera.origin, 
                    .direction = ray_direction 
                };

                const ray_color = try cast_ray(ray);

                try pixels.append(ray_color); 
            }
        }

        const delta_time_nano = timer.read();
        timer.reset();
        logger.info("Frame took {d} ms to render", . { delta_time_nano / 1000000 });

        return Image 
        { 
            .width = @as(u32, self.dimensions.width), 
            .height = @as(u32, self.dimensions.height), 
            .pixels = pixels
        };
    }

    fn cast_ray(ray: Ray) !zm.Vec
    {
        _ = ray; // autofix
        return zm.Vec { 0.0, 0.0, 1.0, 1.0 };
    }

    fn get_viewport_ray_point (camera: *const Camera, ray_coord: zm.Vec) zm.Vec 
    {
        return zm.mulAdd(camera.viewport.pixel_size, ray_coord, camera.viewport.viewport_upper_left);
    }
};

/// Converts a pixel to a UV coordinate. NDC space.
fn pixel_to_uv(pixel: zm.Vec, dimmensions: Dimensions) zm.Vec 
{
    const u: f64 = @as(f64, pixel.x) / @as(f64, dimmensions.width);
    const v: f64 = @as(f64, pixel.y) / @as(f64, dimmensions.height);
    return zm.Vec{ u, v, 0, 1 };
}

fn random_colour() zm.Vec
{
    const time_seed: u64 = @intCast(std.time.milliTimestamp()); // Use current time as seed.
    var rng = std.Random.DefaultPrng.init(time_seed);

    return zm.Vec { rng.random().floatNorm(f32), rng.random().floatNorm(f32), rng.random().floatNorm(f32), 1};
}