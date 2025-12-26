--[[
				             SMWCamera+
	    A Script created to replicate SMW's Camera behavior
		    Original by supermario_2001, Refectored by PURPS
			
	CREDITS:
	supermario_2001 - For creating the original SMWCamera script.
	
	Bonus:
    Partially compatible with "customCamera" by MrDoubleA

    Its also comaptible with "warpTransition by MrDoubleA" BUT
    "warpTransition.sameSectionTransition" has to be set to either mosaic or iris-out
    as i couldn't figure out how to make the camera pan work properly...
	
]]--

local smwCamera = {}

-- Configuration & Constants
local CONFIG = {
    resW = 512, resH = 448, -- SCREEN RESOLUTION, BY DEFAULT IT USES SMW'S 256X244 2x
    regionW = 80, regionH = 112,
    offsetY = 32,
    scrollSpeedY = 325,
    windowSpeedX = 195,
    fastThreshold = 4.0,
    lookAhead = 64
}

-- State Management
local states = {}
local customCamera

-- Public Settings
smwCamera.debug = true
smwCamera.verticalScroll = true
smwCamera.fastSpeedThreshold = Defines.player_runspeed

-- Helpers
local function sign(x) return x > 0 and 1 or x < 0 and -1 or 0 end
local function approach(val, target, speed)
    return (val < target) and math.min(val + speed, target) or math.max(val - speed, target)
end

local function canScrollUp(p, state)
    if not smwCamera.verticalScroll then 
        return state.scrollingUp or p:isOnGround() or p:mem(0x16E, FIELD_BOOL) 
    end
    
    -- Always scroll if already scrolling
    if state.scrollingUp then return true end
    
    -- If the player is on the ground, allow scrolling up.
    if p:isOnGround() then
        return true
    -- If the player isn't on the ground, but they are at max speed, allow scrolling up.
    else
        if p.speedX and math.abs(p.speedX) >= (smwCamera.fastSpeedThreshold or CONFIG.fastThreshold) then
            return true
        end
    end
    
    -- Scroll if flying
    if p:mem(0x16E, FIELD_BOOL) then return true end
    
    -- Scroll if climbing on vines
    if p:isClimbing() then return true end
    
    -- If the player is swimming, allow scrolling up.
    if p:isUnderwater() then return true end

    -- Otherwise, don't scroll
    return false
end

-- Logic: Handle Custom Camera Library Bounds
local function applyCustomBounds(cam, p, state)
    if not customCamera or not customCamera.currentBounds then return end
    
    local b = customCamera.currentBounds
    if b[1] then state.x = math.max(state.x, b[1]) end
    if b[2] then state.x = math.min(state.x, b[2] - cam.width) end
    if b[3] then state.y = math.max(state.y, b[3]) end
    if b[4] then state.y = math.min(state.y, b[4] - cam.height) end

    local s = customCamera.currentSettings
    if s and s.treatCameraBoundsAsPhysical and p.deathTimer == 0 and p.forcedState == 0 then
        local fx, fy, fw, fh = customCamera.getFullCameraPos()
        
        if p.x <= fx then
            p.x, p.speedX = fx, math.max(0, p.speedX)
            p:mem(0x148, FIELD_WORD, 2)
        elseif p.x >= fx + fw - p.width then
            p.x, p.speedX = fx + fw - p.width, math.min(0, p.speedX)
            p:mem(0x14C, FIELD_WORD, 2)
        end
        
        if p.y >= fy + fh + 64 then 
            p:kill() 
        else
            p.y = math.max(p.y, fy - p.height - 32)
        end
    end
end

-- Main Logic Loop
local function updateCameraState(idx, cam, p)
    if not states[idx] then
        states[idx] = {
            x = cam.x, y = cam.y,
            windowX = cam.width/2 - 96,
            targetWindowX = -48,
            scrollingUp = false,
            locked = false
        }
    end
    local s = states[idx]
    if s.locked then 
        cam.x, cam.y = s.lockedX or cam.x, s.lockedY or cam.y
        return 
    end

    local dt = 1 / Misc.GetEngineTPS()

    -- 1. Horizontal Logic
    local winTarget = (cam.width / 2) - (CONFIG.regionW / 2) + s.targetWindowX - (8 * sign(s.targetWindowX))
    s.windowX = approach(s.windowX, winTarget, CONFIG.windowSpeedX * dt)

    local relX = p.x - s.x
    if relX < s.windowX then
        if p.direction == -1 then s.targetWindowX = CONFIG.lookAhead end
        s.x = s.x - (s.windowX - relX)
    elseif relX + p.width > s.windowX + CONFIG.regionW then
        if p.direction == 1 then s.targetWindowX = -CONFIG.lookAhead end
        s.x = s.x + ((relX + p.width) - (s.windowX + CONFIG.regionW))
    end

    -- 2. Vertical Logic (Fixed to support both modes)
    local regionY = (cam.height / 2) - (CONFIG.regionH / 2) + CONFIG.offsetY
    local relY = p.y - s.y

    if smwCamera.verticalScroll then
        -- SMW behavior: smooth scroll up, instant snap down
        if relY < regionY and canScrollUp(p, s) then
            s.scrollingUp = true
            
            -- Calculate the target Y (where the player is exactly at the top margin)
            local targetY = p.y - regionY
            
            -- Move camera UP (decrease Y) by speed, but do not overshoot
            s.y = math.max(targetY, s.y - (CONFIG.scrollSpeedY * dt))
            
        elseif relY + p.height > regionY + CONFIG.regionH then
            -- Instant Snap Down
            s.scrollingUp = false
            s.y = s.y + ((relY + p.height) - (regionY + CONFIG.regionH))
        else
            s.scrollingUp = false
        end
    else
        -- SMBX behavior: instant snap both directions
        if relY < regionY then
            s.y = s.y - (regionY - relY)
        elseif relY + p.height > regionY + CONFIG.regionH then
            s.y = s.y + ((relY + p.height) - (regionY + CONFIG.regionH))
        end
    end

    -- 3. Apply Bounds
    applyCustomBounds(cam, p, s)
    
    local bounds = p.sectionObj.boundary
    s.x = math.clamp(s.x, bounds.left, bounds.right - cam.width)
    s.y = math.clamp(s.y, bounds.top, bounds.bottom - cam.height)

    cam.x, cam.y = s.x, s.y

    -- 4. Debug Visualization
    if smwCamera.debug then
        local relX = p.x - s.x
        local relY = p.y - s.y
        
        -- Horizontal region (dynamic window)
        Graphics.drawBox{x = s.windowX, y = 0, w = CONFIG.regionW, h = cam.height, color = Color.black..0.5}
        
        -- Vertical region (static)
        Graphics.drawBox{x = 0, y = regionY, w = cam.width, h = CONFIG.regionH, color = Color.red..0.5}
        
        -- Player hitbox
        Graphics.drawBox{x = relX, y = relY, w = p.width, h = p.height, color = Color.white..0.5}
        
        -- Status text
        local mode = smwCamera.verticalScroll and "SMW" or "SMBX"
        local tags = {}
        if s.scrollingUp then table.insert(tags, "↑") end
        if p:mem(0x16E, FIELD_BOOL) then table.insert(tags, "FREE") end
        if customCamera and customCamera.currentBounds then table.insert(tags, "Bounds") end
        
        local status = mode .. (#tags > 0 and " [" .. table.concat(tags, "|") .. "]" or "")
        Text.print(status, 3, 16, 420)
    end
end

-- API Hooks
function smwCamera.onInitAPI()
    registerEvent(smwCamera, "onStart")
    registerEvent(smwCamera, "onCameraUpdate")
    registerEvent(smwCamera, "onWarp")
    
    -- Load customCamera library if available
    customCamera = package.loaded["customCamera"] or 
                   package.loaded["libraries/customCamera"] or 
                   package.loaded["libraries.customCamera"] or 
                   package.loaded["libs/customCamera"] or 
                   package.loaded["libs.customCamera"]
    
    if customCamera and smwCamera.debug then
        print("[smwCamera] customCamera detected")
    end
end

function smwCamera.onStart()
    Graphics.setMainFramebufferSize(CONFIG.resW, CONFIG.resH)
end

function smwCamera.onWarp(warp, p)
    local cam = Camera(p.idx)
    if states[p.idx] then
        states[p.idx].x = p.x - cam.width/2 - p.width/2
        states[p.idx].y = p.y - cam.height/2 - p.height/2
        states[p.idx].scrollingUp = false
    end
end

function smwCamera.onCameraUpdate(idx)
    local cam = Camera(idx)
    local p = Player(idx)
    if cam and cam.isValid and p and p.isValid then
        cam.width, cam.height = Graphics.getMainFramebufferSize()
        updateCameraState(idx, cam, p)
    end
end

function smwCamera.setCameraLocked(cam, locked)
    if not states[cam.idx] then return end
    states[cam.idx].locked = locked
    if locked then
        states[cam.idx].lockedX = cam.x
        states[cam.idx].lockedY = cam.y
    end
end

return smwCamera