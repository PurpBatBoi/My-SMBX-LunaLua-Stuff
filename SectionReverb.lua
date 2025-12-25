--[[
    SectionReverb - Dynamically swap sound effects based on which section the player is in

    Usage in the Stage's "luna.lua":
        local SectionReverb = require("SectionReverb")

        function onStart()
            -- Tell it which sections should use echo sounds
            SectionReverb.setEchoSections({
                [2] = true,  -- section 2 uses echo
                [5] = true   -- section 5 uses echo
            })

            -- Register your sounds (only echo versions are required in YOUR-EPISODE/sound/echo/)
            -- If no custom normal sound exists, it uses the base SMBX sound
            SectionReverb.register(14, "coin")  -- uses base SMBX coin +  YOUR-EPISODEsound/echo/coin.ogg
            SectionReverb.register(1, "jump")   -- or  YOUR-EPISODE/sound/jump.ogg +  YOUR-EPISODE/sound/echo/jump.ogg if both exist

            Tbh you should register ALL of your sounds in some other lua file then load that to say which sfx will make use of this library
        end

    The library handles the rest - sounds automatically switch when you change sections.
--]]

local SectionReverb = {}

local ReverbSections = {}
local registeredSounds = {}
local lastSection = -1
local commonExtensions = { "opus", "flac", "ogg", "wav", "mp3" }

function SectionReverb.register(id, filename, echoFilename)
    echoFilename = echoFilename or filename

    local function findFile(path)
        if path:match("%.%w+$") then
            return Misc.resolveFile(path)
        end

        for _, ext in ipairs(commonExtensions) do
            local found = Misc.resolveFile(path .. "." .. ext)
            if found then return found end
        end
        return nil
    end

    local normalPath = findFile(filename) or findFile("sound/" .. filename)
    local echoPath = findFile("sound/echo/" .. echoFilename)

    -- Allow echo-only registration (uses base SMBX sound as normal)
    if echoPath then
        registeredSounds[id] = {
            normal = normalPath and SFX.open(normalPath) or (Audio.sounds[id] and Audio.sounds[id].sfx),
            echo = SFX.open(echoPath)
        }
        SectionReverb.updateSound(id)
    else
        Misc.warn("SectionReverb: " .. filename .. " registration failed. Missing Echo.")
    end
end

function SectionReverb.setEchoSections(sectionsTable)
    ReverbSections = sectionsTable
    for id, _ in pairs(registeredSounds) do
        SectionReverb.updateSound(id)
    end
end

function SectionReverb.updateSound(id)
    local data = registeredSounds[id]
    if not data then return end

    if Audio.sounds[id] then
        local useEcho = ReverbSections[player.section]
        if useEcho then
            Audio.sounds[id].sfx = data.echo
        else
            Audio.sounds[id].sfx = data.normal
        end
    end
end

function SectionReverb.onTick()
    if player.section ~= lastSection then
        for id, _ in pairs(registeredSounds) do
            SectionReverb.updateSound(id)
        end
        lastSection = player.section
    end
end

function SectionReverb.onStart()
    lastSection = player.section
    for id, _ in pairs(registeredSounds) do
        SectionReverb.updateSound(id)
    end
end

registerEvent(SectionReverb, "onTick")
registerEvent(SectionReverb, "onStart")

return SectionReverb
