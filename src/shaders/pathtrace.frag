#version 460

struct Colour 
{
    float r;
    float g;
    float b;
    float a;
};

layout(set = 0, binding = 0, std430) buffer PixelBuffer {
    Colour colours[];
} pixelBuffer;
   
// Define a struct for dimensions
struct Dimensions 
{
    int width;
    int height;
};

// Declare a uniform buffer object for Dimensions
layout(set = 0, binding = 1) uniform DimBuffer 
{
    Dimensions dims;
} dimBuffer;

layout(location = 0) in vec2 fragTexCoord;
layout(location = 0) out vec4 outColor;

void main() 
{
    int width = dimBuffer.dims.width;
    int height = dimBuffer.dims.height;

    // Scale fragTexCoord to the resolution
    int x = int(fragTexCoord.x * float(width));
    int y = int(fragTexCoord.y * float(height));

    // Calculate the corresponding index in the 1D array
    int index = y * width + x;
    
    outColor = vec4(pixelBuffer.colours[index].r, pixelBuffer.colours[index].g, pixelBuffer.colours[index].b, pixelBuffer.colours[index].a);
    //outColor = vec4(fragTexCoord.x, fragTexCoord.y, 0, 1);
}