local pixel_rendering = {}

-- Scene capture priority (Blocks, NPCs, Player)
pixel_rendering.renderPriority = -4
-- Background capture priority (Just the sky/image)
pixel_rendering.bgPriority = -100

pixel_rendering.config = {
    width = 800,
    height = 600,
    pixelSize = 2
}

local screenBuffer
local bgBuffer -- New buffer for the HD background
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
    
    if not screenBuffer then
        screenBuffer = Graphics.CaptureBuffer(pixel_rendering.config.width, pixel_rendering.config.height)
    end
    
    -- Initialize the Background Buffer
    if not bgBuffer then
        bgBuffer = Graphics.CaptureBuffer(pixel_rendering.config.width, pixel_rendering.config.height)
    end
    
    if not shader then
        shader = Shader()
        shader:compileFromFile(nil, "pixel_rendering.frag")
    end
end

function pixel_rendering.onInitAPI()
    registerEvent(pixel_rendering, "onDraw")
end

function pixel_rendering.getviewportsize()
    return pixel_rendering.config.width, pixel_rendering.config.height
end

function pixel_rendering.onDraw()
    -- 1. Capture ONLY the background (HD Reference)
    bgBuffer:captureAt(pixel_rendering.bgPriority)
    
    -- 2. Capture the Scene (Pixelated Target)
    screenBuffer:captureAt(pixel_rendering.renderPriority)
    
    local w, h = pixel_rendering.getviewportsize()
    local cam = Camera.get()[1] 
    
    Graphics.drawScreen{
        texture = screenBuffer,
        shader = shader,
        priority = pixel_rendering.renderPriority,
        uniforms = {
            iResolution = {w, h},
            iPixelSize = pixel_rendering.config.pixelSize,
            iCamPos = {cam.x, cam.y},
            iBgTexture = bgBuffer -- Send the HD background to the shader
        }
    }
end

return pixel_rendering