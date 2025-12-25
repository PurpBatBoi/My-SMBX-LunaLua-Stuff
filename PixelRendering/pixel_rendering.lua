local pixel_rendering = {}

pixel_rendering.renderPriority = -4

pixel_rendering.config = {
    width = 800,
    height = 600,
    pixelSize = 2
}

local screenBuffer
local shader

local function mergeConfig(userConfig)
    if not userConfig then return end
    for k, v in pairs(userConfig) do
        if pixel_rendering.config[k] ~= nil then
            pixel_rendering.config[k] = v
        end
    end
end

function pixel_rendering.init(config)
    mergeConfig(config)
    
    -- Initialize the buffer
    if not screenBuffer then
        screenBuffer = Graphics.CaptureBuffer(pixel_rendering.config.width, pixel_rendering.config.height)
    end
    
    -- Initialize the shader
    if not shader then
        shader = Shader()
        -- Ensure you use the correct path with forward slash
        shader:compileFromFile(nil, "pixel_rendering.frag")
    end
end

function pixel_rendering.onInitAPI()
    -- REMOVED: registerEvent(pixel_rendering, "onCameraUpdate") <- This caused the stutter!
    registerEvent(pixel_rendering, "onDraw")
end

function pixel_rendering.getviewportsize()
    return pixel_rendering.config.width, pixel_rendering.config.height
end

function pixel_rendering.onDraw()
    -- Capture the screen normally
    screenBuffer:captureAt(pixel_rendering.renderPriority)
    
    local w, h = pixel_rendering.getviewportsize()
    
    -- Get current camera position
    local cam = Camera.get()[1] 
    
    Graphics.drawScreen{
        texture = screenBuffer,
        shader = shader,
        priority = pixel_rendering.renderPriority,
        uniforms = {
            iResolution = {w, h},
            iPixelSize = pixel_rendering.config.pixelSize,
            -- We pass the camera offset so the shader can align the grid to the world
            iCamPos = {cam.x, cam.y}
        }
    }
end

return pixel_rendering