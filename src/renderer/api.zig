const vk = @import("vulkan");

pub const API_DEFINITION: []const vk.ApiInfo = &.{api};

const api = vk.ApiInfo
{
    .base_commands = 
    .{
        .createInstance = true,
        .getInstanceProcAddr = true,
        .enumerateInstanceLayerProperties = true,        
    },
    .instance_commands = 
    .{
        .destroyInstance = true,
        .createDebugUtilsMessengerEXT = true,
        .getPhysicalDeviceSurfaceSupportKHR = true,
        .getPhysicalDeviceQueueFamilyProperties = true,
        .enumerateDeviceExtensionProperties = true, 
        .enumeratePhysicalDevices = true,
        .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
        .getPhysicalDeviceSurfaceFormatsKHR = true,
        .getPhysicalDeviceSurfacePresentModesKHR = true,
        .createDevice = true,
        .getDeviceProcAddr = true,
        .destroySurfaceKHR = true,
        .destroyDebugUtilsMessengerEXT = true,
    },
    .device_commands = 
    .{
        .getDeviceQueue = true,
        .createImageView = true,
        .createSwapchainKHR = true,
        .getSwapchainImagesKHR = true,
        .createRenderPass = true,
        .createGraphicsPipelines = true,
        .createShaderModule = true,
        .createFence = true,
        .createSemaphore = true,
        .destroyShaderModule = true,
        .createPipelineLayout = true,
        .createFramebuffer = true,
        .createCommandPool = true,
        .allocateCommandBuffers = true,
        .beginCommandBuffer = true,
        .queueSubmit = true,
        .resetFences = true,
        .waitForFences = true,
        .acquireNextImageKHR = true,
        .cmdBindPipeline = true,
        .endCommandBuffer = true,
        .resetCommandBuffer = true,
        .cmdSetViewport = true,
        .cmdSetScissor = true,
        .cmdDraw = true,
        .cmdBeginRenderPass = true,
        .cmdEndRenderPass = true,
        .queuePresentKHR = true,   
        .deviceWaitIdle = true,
        .destroySemaphore = true,
        .destroyFence = true,
        .destroyImageView = true,
        .destroyFramebuffer = true,
        .destroyPipeline = true,
        .destroyPipelineLayout = true,  
        .destroyDevice = true,
        .destroyCommandPool = true,
        .destroySwapchainKHR = true,
        .destroyRenderPass = true,
    }
};

