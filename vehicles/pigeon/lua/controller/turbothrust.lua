-- TurboThrust Controller
-- Handles Jet Propulsion logic for XXXL Turbo
-- v6: Robust RPM fetch from Electrics
local M = {}

-- IDs for physics application
local turboInId = nil
local turboExhId = nil

-- Caching
local cachedDevice = nil
local cachedDeviceType = nil -- "turbo" or "engine"
local timer = 0

local function logDebug(msg)
    log('I', 'turbothrust', msg)
end

-- Init function
local function init(jbeamData)
    logDebug('Initializing TurboThrust Controller (v7 ENGINE FORCE)...')
    
    turboInId = nil
    turboExhId = nil
    engineNodeId = nil
    cachedDevice = nil
    
    if v and v.data and v.data.nodes then
        for id, node in pairs(v.data.nodes) do
            if type(node) == "table" then
                if node.name == "turboin" then 
                    turboInId = id 
                end
                if node.name == "turboexh" then 
                    turboExhId = id 
                end
                -- Grab an engine node to be sure we are pushing the dense part of the car
                if node.name == "e1r" then
                    engineNodeId = id
                end
            end
        end
    end
    
    -- Fallback engine node if e1r not found (look for any node)
    if not engineNodeId and v.data.nodes then
         for id, node in pairs(v.data.nodes) do
            if type(node) == "table" and node.name and string.find(node.name, "e1") then
                engineNodeId = id
                break
            end
         end
    end

    if turboInId and turboExhId then
        logDebug("Nodes Found: In="..tostring(turboInId).." Exh="..tostring(turboExhId).." Eng="..tostring(engineNodeId))
    else
        logDebug("Nodes MISSING during init")
    end
end

-- Helper to find driving device (Turbo or Engine)
local function scanForDevice()
    if cachedDevice then 
        return cachedDevice, cachedDeviceType 
    end

    -- 1. Try Turbo
    local t = powertrain.getDevice("turbocharger")
    if t then 
        cachedDevice = t
        cachedDeviceType = "turbo"
        return t, "turbo"
    end

    -- 2. Scan for Turbo
    local devices = powertrain.getDevices()
    if devices then
        for name, device in pairs(devices) do
            if device and (device.type == "turbocharger" or string.find(string.lower(tostring(name)), "turbo")) then
                cachedDevice = device
                cachedDeviceType = "turbo"
                return device, "turbo"
            end
        end
    end
    
    -- 3. Fallback to Main Engine
    local eng = powertrain.getDevice("mainEngine")
    if eng then
        cachedDevice = eng
        cachedDeviceType = "engine"
        return eng, "engine"
    end
    
    return nil, nil
end

-- Physics Update (2000Hz)
local function update(dt)
    local device, devType = scanForDevice()
    
    -- Robust RPM Fetch
    local rpm = 0
    if device then
        rpm = device.rpm or 0
    end
    
    -- Universal Fallback: Use Electrics (Game Tacho RPM)
    -- This works even if powertrain is acting weird (e.g. stalled engine device but rolling start)
    if rpm < 1 and electrics and electrics.values.rpm then
        rpm = electrics.values.rpm
    end
    
    if rpm < 0 then rpm = 0 end

    local thrustFactor = 0
    
    -- BOOST BASED THRUST LOGIC
    local boost = 0
    if electrics and electrics.values.boost then
        boost = electrics.values.boost
    end
    
    local boostThreshold = 5 -- PSI (Lowered to 5psi for easier activation)
    local maxBoost = 150 -- PSI (Approximate max for XXXL turbo)
    
    if boost > boostThreshold then
        local rawFactor = (boost - boostThreshold) / (maxBoost - boostThreshold)
        -- Non-linear curve (power 1.5): Slower start, faster ramp up at high boost
        thrustFactor = math.pow(rawFactor, 1.5)
    end
    
    -- Clamp 0-1
    if thrustFactor > 1 then 
        thrustFactor = 1 
    end
    if thrustFactor < 0 then 
        thrustFactor = 0 
    end
    
    -- Export electrics for JBeam Thrusters
    if electrics then
        electrics.values.jetThrust = thrustFactor
    end
end

-- GFX Update (Visuals, ~60Hz)
local function updateGFX(dt)
    timer = timer + dt
    if timer < 0.1 then 
        return 
    end
    timer = 0
    
    local device, devType = scanForDevice()
    local rpm = 0
    local label = "Turbo RPM"
    
    -- Priority: Real Turbo RPM
    if device and devType == "turbo" then
        rpm = device.rpm or 0
    elseif electrics and electrics.values.rpm then
        -- Only fallback if turbo completely missing, but label it clearly
        rpm = electrics.values.rpm
        label = "Eng RPM (Fallback)"
    end
    
    local boost = 0
    if electrics and electrics.values.boost then
        boost = electrics.values.boost
    end

    local thrust = 0
    if electrics and electrics.values then
        thrust = electrics.values.jetThrust or 0
    end
    
    local force = thrust * 4500
    
    if gui then
        local msg = string.format("XXXL JET DEBUG\n%s: %.0f\nBoost: %.2f psi\nForce: %.0f N", label, rpm, boost, force)
        gui.message(msg, 5, "turboinfo")
    end

    -- Flame Effect (High Thrust)
    -- "After smoke ends" -> Assuming high RPM/Power
    if thrust > 0.75 and turboExhId and turboInId and obj then
        -- Particle Type 48 = Fire/Explosion variant
        -- Direction: turboExh -> turboIn (Based on JBeam Thruster direction being In->Exh)
        -- We want reaction direction (Out the back)
        local speed = 40 + (thrust * 40) -- 40 to 80 m/s
        local count = math.floor(thrust * 3) -- 1 to 3 particles
        
        -- Add some randomness
        if math.random() > 0.3 then
            obj:addParticleByNodes(turboExhId, turboInId, speed, 48, count, 1, 0)
        end
    end
end

-- Public Interface
M.init = init
M.update = update 
M.updateGFX = updateGFX

return M
