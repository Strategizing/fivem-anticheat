-- NexusGuard Anti-Cheat Test Cases
-- This file defines test cases for the anti-cheat system

local testCases = {
    {
        name = "Speed hack detection",
        run = function()
            local detected = false
            for _, detection in ipairs(testResults.detections or {}) do
                if detection.type:lower() == "speedhack" then
                    detected = true
                    break
                end
            end
            return detected, "Speed hack was " .. (detected and "detected" or "not detected")
        end,
        teardown = function()
            if _G._originalGetEntityVelocity then
                _G.GetEntityVelocity = _G._originalGetEntityVelocity
            end
        end,
        expectation = true
    },
    {
        name = "God mode detection",
        setup = function()
            _G._originalGetPlayerInvincible = GetPlayerInvincible
            _G.GetPlayerInvincible = function() return true end
        end,
        run = function()
            TriggerEvent("NexusGuard:DetectGodMode")
            Citizen.Wait(100)
            local detected = false
            for _, detection in ipairs(testResults.detections or {}) do
                if detection.type:lower() == "godmode" then
                    detected = true
                    break
                end
            end
            return detected, "God mode was " .. (detected and "detected" or "not detected")
        end,
        teardown = function()
            if _G._originalGetPlayerInvincible then
                _G.GetPlayerInvincible = _G._originalGetPlayerInvincible
            end
        end,
        expectation = true
    },
    {
        name = "Weapon modification detection",
        setup = function()
            _G._originalGetWeaponDamage = GetWeaponDamage
            _G.GetWeaponDamage = function() return 1000.0 end
        end,
        run = function()
            TriggerEvent("NexusGuard:DetectWeaponModification")
            Citizen.Wait(100)
            local detected = false
            for _, detection in ipairs(testResults.detections or {}) do
                if detection.type:lower() == "weaponmod" then
                    detected = true
                    break
                end
            end
            return detected, "Weapon modification was " .. (detected and "detected" or "not detected")
        end,
        teardown = function()
            if _G._originalGetWeaponDamage then
                _G.GetWeaponDamage = _G._originalGetWeaponDamage
            end
        end,
        expectation = true
    }
}

return testCases