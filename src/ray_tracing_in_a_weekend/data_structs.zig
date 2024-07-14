const std = @import("std");

const zm = @import("zmath");

pub const Camera = struct
{
    origin: zm.Vec,
    view_direction: zm.Vec,
    near_clip_distance: f32,
    viewport: ViewPort
};

pub const Dimensions = struct 
{
    width: u32,
    height: u32,
    aspect_ratio: f32,
};

pub const ViewPort = struct 
{
    width: f32,
    height: f32,
    viewport_upper_left: zm.Vec,
    pixel_size: zm.Vec
};

// pub const Point2D = struct {
//     x: f64,
//     y: f64,

//     pub fn zero() Point2D
//     {
//         return Point2D { .x = 0.0, .y = 0.0 };
//     }

//     pub fn one() Point2D
//     {
//         return Point2D { .x = 1.0, .y = 1.0 };
//     }

//     pub fn add(self: Point2D, other: Point2D) Point2D
//     {
//         return Point2D { .x = self.x + other.x, .y = self.y + other.y };
//     }

//     pub fn sub(self: Point2D, other: Point2D) Point2D
//     {
//         return Point2D { .x = self.x - other.x, .y = self.y - other.y };
//     }

//     pub fn mul(self: Point2D, other: Point2D) Point2D
//     {
//         return Point2D { .x = self.x * other.x, .y = self.y * other.y };
//     }

//     pub fn div(self: Point2D, other: Point2D) Point2D
//     {
//         return Point2D { .x = self.x / other.x, .y = self.y / other.y };
//     }
// };

// pub const Point3D = struct {
//     x: f64,
//     y: f64,
//     z: f64,

//     pub fn zero() Point3D
//     {
//         return Point3D { .x = 0.0, .y = 0.0, .z = 0.0 };
//     }

//     pub fn one() Point3D
//     {
//         return Point3D { .x = 1.0, .y = 1.0, .z = 1.0 };
//     }

//     pub fn add(self: *const Point3D, other: Point3D) Point3D
//     {
//         return Point3D { .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
//     }

//     pub fn sub(self: *const Point3D, other: Point3D) Point3D
//     {
//         return Point3D { .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
//     }

//     pub fn mul(self: *const Point3D, other: Point3D) Point3D
//     {
//         return Point3D { .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
//     }

//     pub fn div(self: *const Point3D, other: Point3D) Point3D
//     {
//         return Point3D { .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
//     }
    
//     pub fn to_vector(self: *const Point3D) Vector3D
//     {
//         return Vector3D { .x = self.x, .y = self.y, .z = self.z };
//     }
    
//     pub fn new(x: f64, y: f64, z: f64) Point3D
//     {
//         return Point3D { .x = x, .y = y, .z = z };
//     }
// };

// pub const Colour = struct {
//     r: f32,
//     g: f32,
//     b: f32,
//     a: f32,

//     pub fn black() Colour
//     {
//         return Colour { .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 };
//     }

//     pub fn white() Colour
//     {
//         return Colour { .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
//     }

//     pub fn add(self: Colour, other: Colour) Colour
//     {
//         return Colour { .r = self.r + other.r, .g = self.g + other.g, .b = self.b + other.b, .a = self.a + other.a };
//     }

//     pub fn sub(self: Colour, other: Colour) Colour
//     {
//         return Colour { .r = self.r - other.r, .g = self.g - other.g, .b = self.b - other.b, .a = self.a - other.a };
//     }   

//     pub fn mul(self: Colour, other: Colour) Colour
//     {
//         return Colour { .r = self.r * other.r, .g = self.g * other.g, .b = self.b * other.b, .a = self.a * other.a };
//     }   

//     pub fn div(self: Colour, other: Colour) Colour
//     {
//         return Colour { .r = self.r / other.r, .g = self.g / other.g, .b = self.b / other.b, .a = self.a / other.a };
//     }   

//     pub fn to_byte_colour(self: Colour) ByteColour
//     {
//         return ByteColour 
//         { 
//             .r = @intCast(self.r * 255.99), 
//             .g = @intCast(self.g * 255.99), 
//             .b = @intCast(self.b * 255.99), 
//             .a = @intCast(self.a * 255.99) 
//         };
//     }
// };

// const ByteColour = struct 
// {
//     r: u8,
//     g: u8,
//     b: u8,
//     a: u8,
// };

// pub const Vector3D = struct
// {
//     x: f64,
//     y: f64,
//     z: f64,

//     pub fn zero() Vector3D
//     {
//         return Vector3D { .x = 0.0, .y = 0.0, .z = 0.0 };
//     }

//     pub fn one() Vector3D
//     {
//         return Vector3D { .x = 1.0, .y = 1.0, .z = 1.0 };
//     }

//     pub fn add(self: *const Vector3D, other: Vector3D) Vector3D
//     {
//         return Vector3D { .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
//     }

//     pub fn sub(self: *Vector3D, other: Vector3D) Vector3D
//     {
//         return Vector3D { .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
//     }

//     pub fn mul(self: *const Vector3D, other: Vector3D) Vector3D
//     {
//         return Vector3D { .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
//     }

//     pub fn mul_f64(self: *Vector3D, other: f64) Vector3D
//     {
//         return Vector3D { .x = self.x * other, .y = self.y * other, .z = self.z * other };
//     }

//     pub fn div(self: *const Vector3D, other: Vector3D) Vector3D
//     {
//         return Vector3D { .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
//     }

//     pub fn dot(self: *const Vector3D, other: Vector3D) f64
//     {
//         return self.x * other.x + self.y * other.y + self.z * other.z;
//     }

//     pub fn cross(self: *Vector3D, other: Vector3D) Vector3D
//     {
//         return Vector3D 
//         { 
//             .x = self.y * other.z - self.z * other.y, 
//             .y = self.z * other.x - self.x * other.z, 
//             .z = self.x * other.y - self.y * other.x 
//         };
//     }

//     pub fn length(self: *const Vector3D) f64
//     {
//         return std.math.sqrt(self.dot(@constCast(self).*));
//     }

//     /// Normalizes the vector to a unit vector.
//     pub fn unit_vector(self: *const Vector3D) Vector3D
//     {
//         const mag = self.length();
//         return self.div(Vector3D { .x = mag, .y = mag, .z = mag });
//     }

//     pub fn to_point(self: *const Vector3D) Point3D
//     {
//         return Point3D { .x = self.x, .y = self.y, .z = self.z };
//     }

//     pub fn foward() Vector3D
//     {
//         return Vector3D { .x = 0.0, .y = 0.0, .z = 1.0 };
//     }
// };

// pub const Vector2D = struct 
// {
//     x: f64,
//     y: f64,
// };

pub const Image = struct
{
    width: u32,
    height: u32,
    pixels: []zm.Vec,

    pub fn mem_size(self: *const Image) u32
    {
        return @sizeOf(zm.Vec) * (self.width * self.height);
    }
};

pub const Ray = struct
{
    origin: zm.Vec,
    direction: zm.Vec, // must be normaized/unit vector

    pub fn at(self: *Ray, t: f64) zm.Vec
    {
        return zm.mulAdd(self.direction, t, self.origin);
    }
};

// Assuming you have defined these somewhere
pub const Light = struct 
{
    direction: zm.Vec,
    color: zm.Vec, // RGB color
    intensity: f32,
};

pub const Cube = struct
{    
    colour: zm.Vec,
    world_position: zm.Vec,
    local_position: zm.Vec = zm.Vec { 0, 0, 0, 1 },
    size: f32, // length of one side
    half_size: f32,
    rotation: zm.Quat, //changes on rotate    
    rotation_matrix: zm.Mat,  //changes on rotate    
    inverse_rotation_matrix: zm.Mat,  //changes on rotate    
    forward: zm.Vec,
    local_verts: [8]zm.Vec,     
    world_verts: [8]zm.Vec,  //changes on rotate    
    indices: [36]u16,
    local_surface_normals: [6]zm.Vec,
    world_surface_normals: [6]zm.Vec,  //changes on rotate    
    local_vertex_normals: [8]zm.Vec,
    world_vertex_normals: [8]zm.Vec,  //changes on rotate    
    min_vert: zm.Vec, 
    max_vert: zm.Vec,    

    pub fn new(world_position: zm.Vec, size: f32, colour: zm.Vec, euler_rotation: zm.Vec, forward: zm.Vec) Cube
    {
        const rotation = zm.qidentity();
        const rotation_matrix = zm.quatToMat(rotation);
        const local_verts = calculate_verts(size);
        const local_surface_normals = calculate_surface_normals();
        const local_vertex_normals = calculate_vertex_normals(local_verts);

        // Initialize cubeMin and cubeMax with the first vertex
        var min_vert = local_verts[0]; // vertex with smallest values
        var max_vert = local_verts[0]; // vertex with largest values

        // Find the minimum and maximum x, y, and z coordinates
        for (0..local_verts.len) |i| {
            min_vert = zm.min(min_vert, local_verts[i]);
            max_vert = zm.max(max_vert, local_verts[i]);
        }

        var self = Cube 
        { 
            .world_position = world_position, 
            .size = size, .colour = colour, 
            .half_size = size / 2.0,
            .rotation = rotation,
            .rotation_matrix = rotation_matrix,
            .inverse_rotation_matrix = zm.inverse(rotation_matrix),
            .forward = forward,
            .local_verts = local_verts,
            .world_verts = calculate_world_verts(rotation_matrix, world_position, local_verts),            
            .indices = calculate_indices(),
            .local_surface_normals = local_surface_normals,
            .world_surface_normals = calculate_world_surface_normals(rotation_matrix, local_surface_normals),
            .local_vertex_normals = local_vertex_normals,
            .world_vertex_normals = calculate_world_vertex_normals(rotation_matrix, local_vertex_normals),
            .min_vert = min_vert,
            .max_vert = max_vert
        };

        self.rotate(euler_rotation);

        return self;
    }

    pub fn get_euler_rotation(self: *const Cube) zm.Vec
    {
        // vec arr in order of y, x, z / roll, pitch, yaw
        const vec_arr = self.rotation.quatToRollPitchYaw();

        // return in order of x, y, z / pitch, roll, yaw
        return zm.Vec { .x = vec_arr[1], .y = vec_arr[0], .z = vec_arr[2] };
    }

    pub fn rotate(self: *Cube, euler_angles_XYZ: zm.Vec) void
    {
        // rotation: zm.Quat changes on rotate    
        // rotation_matrix: zm.Mat changes on rotate    
        // inverse_rotation_matrix: zm.Mat changes on rotate   
        // world_verts: [8]zm.Vec changes on rotate
        // world_surface_normals: [6]zm.Vec, changes on rotate    
        // world_vertex_normals: [8]zm.Vec,  changes on rotate        

        //const rot_delta = zm.quatFromRollPitchYaw(euler_angles_XYZ[0], euler_angles_XYZ[1], euler_angles_XYZ[2]);        
        //self.rotation = zm.rotate(self.rotation, zm.Vec { euler_angles_XYZ[1], euler_angles_XYZ[0], euler_angles_XYZ[2], 1});
        //self.rotation_matrix = zm.quatToMat(self.rotation);
        
        const rotation_delta = zm.matFromRollPitchYawV(euler_angles_XYZ);
        self.rotation_matrix = zm.mul(rotation_delta, self.rotation_matrix);
        self.rotation = zm.matToQuat(self.rotation_matrix);
        self.inverse_rotation_matrix = zm.inverse(self.rotation_matrix);

        self.world_verts = calculate_world_verts(self.rotation_matrix, self.world_position, self.local_verts);
        self.world_surface_normals = calculate_world_surface_normals(self.inverse_rotation_matrix, self.local_surface_normals);
        self.world_vertex_normals = calculate_world_vertex_normals(self.rotation_matrix, self.local_vertex_normals);
    }

    fn calculate_verts(size: f32) [8]zm.Vec
    {
        const half_size = size / 2.0;
        return [_]zm.Vec {
            zm.Vec { -half_size, -half_size, -half_size, 1 },
            zm.Vec { half_size, -half_size, -half_size, 1 },
            zm.Vec { half_size, half_size, -half_size, 1 },
            zm.Vec { -half_size, half_size, -half_size, 1 },
            zm.Vec { -half_size, -half_size, half_size, 1 },
            zm.Vec { half_size, -half_size, half_size, 1 },
            zm.Vec { half_size, half_size, half_size, 1 },
            zm.Vec { -half_size, half_size, half_size, 1 },
        };
    }

    fn calculate_indices() [36]u16 
    {
        return [_]u16{
            // Front face
            0, 1, 2, 2, 3, 0,
            // Back face
            4, 7, 6, 6, 5, 4,
            // Top face
            2, 6, 7, 7, 3, 2,
            // Bottom face
            0, 4, 5, 5, 1, 0,
            // Right face
            1, 5, 6, 6, 2, 1,
            // Left face
            0, 3, 7, 7, 4, 0,
        };
    }

    fn calculate_surface_normals() [6]zm.Vec 
    {
        return [_]zm.Vec{
            zm.Vec{ 0, 0, 1, 0 },  // Front
            zm.Vec{ 0, 0, -1, 0 }, // Back
            zm.Vec{ 0, 1, 0, 0},  // Top
            zm.Vec{ 0, -1, 0, 0 }, // Bottom
            zm.Vec{ 1, 0, 0, 0 },  // Right
            zm.Vec{ -1, 0, 0, 0 }, // Left
        };
    }

    fn calculate_world_surface_normals(rotation_matrix: zm.Mat, local_surface_normals: [6]zm.Vec) [6]zm.Vec 
    {
        var world_surface_normals: [6]zm.Vec = undefined;

        for (local_surface_normals, 0..) |normal, i| 
        {
            world_surface_normals[i] = zm.mul (rotation_matrix, normal) ;
        }
        return world_surface_normals;
    }

    fn calculate_vertex_normals(verts: [8]zm.Vec) [8]zm.Vec 
    {
        var vertex_normals: [8]zm.Vec = undefined;
        for (verts, 0..) |vert, i| 
        {
            vertex_normals[i] = zm.normalize4(vert);
        }
        return vertex_normals;
    }

    fn calculate_world_vertex_normals(rotation_matrix: zm.Mat, local_vertex_normals: [8]zm.Vec) [8]zm.Vec 
    {
        var world_Vertex_normals: [8]zm.Vec = undefined;

        for (local_vertex_normals, 0..) |normal, i| 
        {
            world_Vertex_normals[i] = zm.mul (rotation_matrix, normal) ;
        }
        return world_Vertex_normals;
    }

    fn calculate_world_verts(rotation_matrix: zm.Mat, position: zm.Vec, verts: [8]zm.Vec) [8]zm.Vec 
    {
        var world_verts: [8]zm.Vec = undefined;

        for (verts, 0..) |vert, i| 
        {
            var v = zm.mul(rotation_matrix, vert);
            v[0] = v[0] + position[0];
            v[1] = v[1] + position[1];
            v[2] = v[2] + position[2];
            v[3] = 1;
            world_verts[i] = v;
        }
        return world_verts;
    }
};