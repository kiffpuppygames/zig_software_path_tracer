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
pub const Light = data_structs.Light;

pub const SoftwarePathTracer = struct 
{
    arena: std.heap.ArenaAllocator,
    dimensions: Dimensions,
    camera: Camera,
    cube: Cube,
    directinonal_light: Light,
    sky_col: zm.Vec = zm.Vec { 0.3, 0.5, 1, 1 },    
    ground_col: zm.Vec = zm.Vec { 0.8, 0.8, 0.8, 1 },
    view_port_ray_points: []zm.Vec = undefined,
    initial_ray_directions: []zm.Vec = undefined,
    intersection_threshold: f32,
    
    pub fn init(width: u32, height: u32, aspect_ratio: f32, near_clip_distance: f32, camera_origin: zm.Vec, intersection_threshold: f32) !SoftwarePathTracer
    {
        const camera_view_direction = zm.Vec { 0, 0, 1, 0};
        const f_width: f32 = @floatFromInt(width);
        const f_height: f32 = @floatFromInt(height);

        const viewport_aspect_ratio: f32 = f_width / f_height;
        const viewport_height: f32 = 3.0;
        const viewport_width = viewport_height * viewport_aspect_ratio;

        const view_port_center = zm.Vec { camera_origin[0], camera_origin[1], camera_origin[2] + near_clip_distance, 1 };
        const viewport_upper_left = zm.Vec { view_port_center[0] + (-viewport_width / 2), view_port_center[1] + (viewport_height / 2), near_clip_distance, 1 };

        const pixel_size = zm.Vec { viewport_width / f_width, viewport_height / f_height, 0, 1 };
        
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
            }
        };

        const dimensions = Dimensions { .width = width, .height = height, .aspect_ratio = aspect_ratio };
        var self = SoftwarePathTracer 
        { 
            .arena = std.heap.ArenaAllocator.init(std.heap.c_allocator),
            .dimensions = dimensions,
            .camera = camera,
            .cube = Cube.new(zm.Vec {0, 0, 3, 1 }, 1, zm.Vec { 0.5, 0.5, 0.5, 1}, zm.Vec { 0, 0, 0, 1 }, zm.Vec { 0, 0, 1, 0 }),    
            .directinonal_light = Light { .color = zm.Vec { 1, 0, 0, 1}, .direction = zm.Vec { 0, 0, -1, 1}, .intensity = 2 },
            .intersection_threshold = intersection_threshold     
        };

        self.view_port_ray_points = try self.arena.allocator().alloc(zm.Vec,self.dimensions.width * self.dimensions.height);
        self.initial_ray_directions = try self.arena.allocator().alloc(zm.Vec,self.dimensions.width * self.dimensions.height);
        //const view_port_ray_point = zm.Vec { self.camera.viewport.viewport_upper_left[0] + (self.camera.viewport.pixel_size[0] * x_float), self.camera.viewport.viewport_upper_left[1] - (self.camera.viewport.pixel_size[1] * y_float), self.camera.viewport.viewport_upper_left[3], 1 };
        
        for (0..self.dimensions.height) |y|
        {
            const y_float: f32 = @floatFromInt(y);
            const row = y * self.dimensions.width;
            for(0..self.dimensions.width) |x|
            {
                const x_float: f32 = @floatFromInt(x);                
                self.view_port_ray_points[row + x] = zm.Vec { 
                    self.camera.viewport.viewport_upper_left[0] + (self.camera.viewport.pixel_size[0] * x_float), 
                    self.camera.viewport.viewport_upper_left[1] - (self.camera.viewport.pixel_size[1] * y_float), 
                    self.camera.viewport.viewport_upper_left[2],
                    1
                };

                self.initial_ray_directions[row + x] = zm.normalize4(zm.Vec { 
                    self.view_port_ray_points[row + x][0] - self.camera.origin[0], 
                    self.view_port_ray_points[row + x][1] - self.camera.origin[1], 
                    self.view_port_ray_points[row + x][2] - self.camera.origin[2], 
                    0}
                );
            }
        }

        return self;
    }

    pub fn generate_frame(
        frame: *Image, 
        camera_origin: zm.Vec, 
        initial_ray_directions: [*]zm.Vec, 
        cube: *const Cube, 
        directinonal_light: *const Light,
        ground_col: *const zm.Vec, 
        sky_col: *const zm.Vec, 
        intersection_threshold: f32) !void
    {
        var ray = Ray 
        { 
            .origin = camera_origin, 
            .direction = undefined,
        };
        var index: usize = undefined;
        var row: usize = undefined;
        var a: f32 = undefined;
        var one_min_a: f32 = undefined;
        const width = frame.width;
        const nrm_d_light_dir = zm.normalize4(directinonal_light.direction);
        //const height = self.dimensions.height;

        for (0..frame.height) |y|
        {            
            row = y * width;
            for(0..width) |x|
            {  
                index = row + x;        
                ray.direction = initial_ray_directions[index];
                a = 0.9 * (ray.direction[1] + 1.7);
                one_min_a = 1 - a;

                const res = ray_intersects_cube(&ray, cube, intersection_threshold);
                if (res != null)
                {
                    const hit_normal = zm.Vec { (res.?[0] + 1) * 0.5, (res.?[1] + 1) * 0.5, (res.?[2] + 1) * 0.5, 1 };

                    const dotNL = zm.dot4(hit_normal, nrm_d_light_dir);
                    const col = zm.max(dotNL, zm.Vec { 0.0, 0.0, 0.0, 0.0 });
                    const diffuse = zm.Vec { col[0] * directinonal_light.intensity, col[1] * directinonal_light.intensity, col[2] * directinonal_light.intensity, 1 }; 

                    const final_color = zm.Vec { cube.colour[0] * diffuse[0], cube.colour[1] * diffuse[1], cube.colour[2] * diffuse[2], 1 };

                    frame.pixels[index] = final_color;
                }
                else 
                {
                    frame.pixels[index] = zm.Vec 
                    {
                        one_min_a * ground_col[0] + a * sky_col[0], 
                        one_min_a * ground_col[1] + a * sky_col[1], 
                        one_min_a * ground_col[2] + a * sky_col[2], 
                        1.0 
                    };
                }
            }
        }
    }
    
    inline fn ray_intersects_cube(world_ray: *const Ray, cube: *const Cube, intersection_threshold: f32) ?zm.Vec 
    {
        var hit_detected = false;

        var t_min: f32 = 0.0; // Start of the ray
        var t_max: f32 = std.math.inf(f32); // End of the ray, can be a large number

        const translated_origin = zm.Vec 
        { 
            world_ray.origin[0] - cube.world_position[0], 
            world_ray.origin[1] - cube.world_position[1], 
            world_ray.origin[2] - cube.world_position[2], 
            1
        };

        const local_ray_origin = zm.mul(cube.inverse_rotation_matrix, translated_origin);
        
        const local_ray_direction = zm.mul(cube.inverse_rotation_matrix, zm.Vec { world_ray.direction[0], world_ray.direction[1], world_ray.direction[2], 0 } );

        for (0..3) |i| 
        {
            if (zm.abs(local_ray_direction[i]) < intersection_threshold) 
            {
                if (local_ray_origin[i] < cube.min_vert[i] or local_ray_origin[i] > cube.max_vert[i]) 
                {
                    break;
                }
            } 
            else 
            {
                const inv_ray_dir = 1.0 / local_ray_direction[i];
                var t1 = (cube.min_vert[i] - local_ray_origin[i]) * inv_ray_dir;
                var t2 = (cube.max_vert[i] - local_ray_origin[i]) * inv_ray_dir;

                if (t1 > t2) std.mem.swap(f32, &t1, &t2);

                t_min = zm.max(t_min, t1);
                t_max = zm.min(t_max, t2);

                if (t_max < t_min) 
                { 
                    hit_detected = false;
                }
                else 
                {
                    hit_detected = true;
                }
            }
        }

        if (hit_detected)
        {
            const bias: f32 = 0.000001;
            //t_min += bias;
            const intersection_point = zm.mulAdd(local_ray_direction, zm.Vec { t_min, t_min, t_min, 0}, local_ray_origin);

            //if (std.math.approxEqAbs(f32, intersection_point[0], cube.min_vert[0], bias)) return cube.world_surface_normals[5]; // Left face
            //if (std.math.approxEqAbs(f32, intersection_point[0], cube.max_vert[0], bias)) return cube.world_surface_normals[4]; //right face
            //if (std.math.approxEqAbs(f32, intersection_point[1], cube.min_vert[1], bias)) return cube.world_surface_normals[3]; //bottom
            //if (std.math.approxEqAbs(f32, intersection_point[1], cube.max_vert[1], bias)) return cube.world_surface_normals[2]; //top
            //if (std.math.approxEqAbs(f32, intersection_point[2], cube.max_vert[2], bias)) return cube.world_surface_normals[0]; //back
            if (std.math.approxEqAbs(f32, intersection_point[2], cube.min_vert[2], bias)) return cube.world_surface_normals[0]; //front
        }

        return null;
    }

    fn get_viewport_ray_point (camera: *const Camera, ray_coord: zm.Vec) zm.Vec 
    {
        return zm.mulAdd(camera.viewport.pixel_size, ray_coord, camera.viewport.viewport_upper_left);
    }

    pub fn deinit(self: *SoftwarePathTracer) !void
    {
        std.heap.c_allocator.free(self.view_port_ray_points);
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