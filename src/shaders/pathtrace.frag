#version 460

struct Pixel 
{
    float r;
    float g;
    float b;
};

layout(set = 0, binding = 0, std430) buffer PixelBuffer {
    Pixel pixels[];
} pixelBuffer;
    

layout(location = 0) in vec2 fragTexCoord;
layout(location = 0) out vec4 outColor;

void main() 
{
    int width = 800; // Assuming a fixed width of 800 pixels
    int height = 600; // Assuming a fixed height of 600 pixels

    // Scale fragTexCoord to the resolution
    int x = int(fragTexCoord.x * float(width));
    int y = int(fragTexCoord.y * float(height));

    // Calculate the corresponding index in the 1D array
    int index = y * width + x;

    if (pixelBuffer.pixels.length() <= 1) // If the pixel has not been written to yet, write to it
    {
        outColor = vec4(1.0, 0.0, 1.0, 1.0);
    }
    else
    {
        outColor = vec4(pixelBuffer.pixels[index].r, pixelBuffer.pixels[index].g, pixelBuffer.pixels[index].b, 1);
    }
}