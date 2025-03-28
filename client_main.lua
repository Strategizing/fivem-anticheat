local NexusGuard = {
    securityToken = nil,
    moduleStatus = {},
    scanIntervals = {
        godMode = 5000,
        weaponModification = 3000,
        speedHack = 2000,
        teleport = 1000,
        noclip = 1000,
        menuDetection = 10000,
        resourceMonitor = 15000
    },
    playerState = {
        position = vec3(0, 0, 0),
        health = 100,
        armor = 0,
        lastTeleport = GetGameTimer(),
        movementSamples = {},
        weaponStats = {}
    },
    flags = {
        suspiciousActivity = false,
        warningIssued = false
    }
}

-- Initialize client-side anti-cheat
Citizen.CreateThread(function()
    while not NetworkIsSessionActive() do
        Citizen.Wait(100)
    end
    
    print('[NexusGuard] Initializing client-side protection...')
    
    -- Get hash of client files for verification
    local clientHash = GetResourceKvpString