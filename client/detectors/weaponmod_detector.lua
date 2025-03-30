local DetectorName = "weaponModification" -- Match the key in Config.Detectors
local Detector = {
    active = false,
    interval = 3000, -- Default, will be overridden by config if available
    lastCheck = 0,
    state = { -- Local state for weapon stats
        weaponStats = {}
    }
}

-- Initialize the detector (called once)
function Detector.Initialize()
    -- Update interval from global config if available
    if Config and Config.Detectors and Config.Detectors.weaponModification and NexusGuard and NexusGuard.intervals and NexusGuard.intervals.weaponModification then
        Detector.interval = NexusGuard.intervals.weaponModification
    end
    print("^2[NexusGuard:" .. DetectorName .. "]^7 Initialized with interval: " .. Detector.interval .. "ms")
    return true
end

-- Start the detector (Called by Registry)
-- The registry now handles the thread creation loop.
function Detector.Start()
    if Detector.active then return false end -- Already active
    Detector.active = true
    -- No need to create thread here, registry does it.
    -- Print statement moved to registry for consistency.
    return true -- Indicate success
end

-- Stop the detector (Called by Registry)
-- The registry relies on this setting the active flag to false.
function Detector.Stop()
    if not Detector.active then return false end -- Already stopped
    Detector.active = false
    -- Print statement moved to registry for consistency.
    return true -- Indicate success
end

-- Check for violations (Moved logic from client_main.lua)
function Detector.Check()
    -- Cache config values locally
    local damageThresholdMultiplier = (Config and Config.Thresholds and Config.Thresholds.weaponDamageMultiplier) or 1.5
    local clipSizeThresholdMultiplier = 2.0 -- Example: Allow double clip size, make configurable if needed

    local ped = PlayerPedId()

    -- Safety checks
    if not DoesEntityExist(ped) then return end

    local currentWeaponHash = GetSelectedPedWeapon(ped)

    -- Only check if player has a weapon equipped (excluding unarmed)
    if currentWeaponHash ~= GetHashKey("WEAPON_UNARMED") then
        -- Get current weapon stats (use natives that return default values if modified)
        -- Note: Relying solely on client-side natives for default values can be bypassed.
        -- A more robust check would involve server-side validation or comparing against known defaults.
        local currentDamage = GetWeaponDamage(currentWeaponHash) -- This might return the modified value
        local currentClipSize = GetWeaponClipSize(currentWeaponHash) -- This might return the modified value

        -- Get default stats (more reliable if available, otherwise use first seen)
        -- Placeholder: Ideally, load default weapon stats from a config or server event
        local defaultDamage = GetWeaponDamage(currentWeaponHash, true) -- Attempt to get default, may not work reliably
        local defaultClipSize = GetWeaponClipSize(currentWeaponHash, true) -- Attempt to get default

        -- Initialize weapon stats in local state if not yet recorded
        if not Detector.state.weaponStats[currentWeaponHash] then
            Detector.state.weaponStats[currentWeaponHash] = {
                -- Store first seen values as a baseline if defaults aren't reliable
                baseDamage = defaultDamage or currentDamage,
                baseClipSize = defaultClipSize or currentClipSize,
                firstSeen = GetGameTimer(),
                samples = 1
            }
            -- print("^3[DEBUG:"..DetectorName.."]^7 Initial stats for " .. currentWeaponHash .. ": Dmg=" .. Detector.state.weaponStats[currentWeaponHash].baseDamage .. ", Clip=" .. Detector.state.weaponStats[currentWeaponHash].baseClipSize)
            return -- Don't check on the very first sample
        end

        local storedStats = Detector.state.weaponStats[currentWeaponHash]

        -- Allow a brief learning phase or require multiple samples
        if GetGameTimer() - storedStats.firstSeen < 10000 and storedStats.samples < 3 then
            storedStats.samples = storedStats.samples + 1
            -- Update baseline if defaults were initially unavailable and now seem stable
            if not defaultDamage and currentDamage ~= storedStats.baseDamage then storedStats.baseDamage = currentDamage end
            if not defaultClipSize and currentClipSize ~= storedStats.baseClipSize then storedStats.baseClipSize = currentClipSize end
            return
        end

        -- Compare current damage against the stored baseline/default
        if storedStats.baseDamage > 0 and currentDamage > (storedStats.baseDamage * damageThresholdMultiplier) then
            if _G.NexusGuard and _G.NexusGuard.ReportCheat then
                _G.NexusGuard:ReportCheat(DetectorName, "Weapon damage modified: " .. currentDamage .. " (Expected baseline: ~" .. storedStats.baseDamage .. ", Threshold: x" .. damageThresholdMultiplier .. ")")
            else
                print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Weapon damage modified: " .. currentDamage .. " (Expected baseline: ~" .. storedStats.baseDamage .. ", Threshold: x" .. damageThresholdMultiplier .. ") (NexusGuard global unavailable)")
            end
        end

        -- Compare current clip size against the stored baseline/default
        if storedStats.baseClipSize > 0 and currentClipSize > (storedStats.baseClipSize * clipSizeThresholdMultiplier) then
             if _G.NexusGuard and _G.NexusGuard.ReportCheat then
                _G.NexusGuard:ReportCheat(DetectorName, "Weapon clip size modified: " .. currentClipSize .. " (Expected baseline: ~" .. storedStats.baseClipSize .. ", Threshold: x" .. clipSizeThresholdMultiplier .. ")")
            else
                print("^1[NexusGuard:" .. DetectorName .. "]^7 Violation: Weapon clip size modified: " .. currentClipSize .. " (Expected baseline: ~" .. storedStats.baseClipSize .. ", Threshold: x" .. clipSizeThresholdMultiplier .. ") (NexusGuard global unavailable)")
            end
        end
    end
end


-- Get detector status
function Detector.GetStatus()
    return {
        active = Detector.active,
        lastCheck = Detector.lastCheck,
        interval = Detector.interval
    }
end

-- Register with the detector system
Citizen.CreateThread(function()
    -- Wait for NexusGuard and DetectorRegistry to initialize
    while not _G.NexusGuard or not _G.DetectorRegistry do
        Citizen.Wait(500)
    end

    -- Initialize after registry is ready
    Detector.Initialize()
    _G.DetectorRegistry.Register(DetectorName, Detector)

    -- Auto-start if enabled in config
    if Config and Config.Detectors and Config.Detectors[DetectorName] then
         -- Small delay to ensure NexusGuard is fully ready
         Citizen.Wait(100)
        _G.DetectorRegistry.Start(DetectorName)
    end
end)
