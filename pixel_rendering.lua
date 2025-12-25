local pixel_rendering = {}

-- Rendering Configuration
-- -100: Backgrounds (HD)
-- -99 to -5: Gameplay Objects (Pixelated)
-- -4: Buffer Draw (Result)
-- -3 to 0: HUD/UI (HD)
pixel_rendering.LAYER_START = -99
pixel_rendering.LAYER_END = -5
pixel_rendering.DRAW_PRIORITY = -4

pixel_rendering.config = {
    width = 800,
    height = 600,
    pixelSize = 2
}

-- Internal resources
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
    
    if not screenBuffer then
        screenBuffer = Graphics.CaptureBuffer(pixel_rendering.config.width, pixel_rendering.config.height)
    end
    
    if not shader then
        shader = Shader()
        shader:compileFromFile(nil, "pixel_rendering.frag")
    end
end

function pixel_rendering.onInitAPI()
    registerEvent(pixel_rendering, "onTick")
    registerEvent(pixel_rendering, "onDraw")
end

function pixel_rendering.onTick()
    if not screenBuffer then return end

    -- Reset buffer transparency
    screenBuffer:clear(0)
    
    -- Redirect standard gameplay layers to the off-screen buffer
    Graphics.redirectCameraFB(screenBuffer, pixel_rendering.LAYER_START, pixel_rendering.LAYER_END)
end

function pixel_rendering.onDraw()
    if not shader or not screenBuffer then return end

    local cam = Camera.get()[1]
    
    -- Draw the processed gameplay layer over the HD background
    Graphics.drawScreen{
        texture = screenBuffer,
        shader = shader,
        priority = pixel_rendering.DRAW_PRIORITY,
        uniforms = {
            iResolution = {pixel_rendering.config.width, pixel_rendering.config.height},
            iPixelSize = pixel_rendering.config.pixelSize,
            iCamPos = {cam.x, cam.y}
        }
    }
end

return pixel_rendering