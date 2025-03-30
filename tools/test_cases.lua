-- NexusGuard Anti-Cheat Test Cases
-- This file defines test cases for the anti-cheat system

local testCases = {
    {
        name = "Speed hack detection",
        description = "Tests if the anti-cheat can detect abnormal movement speeds",
        setup = function()
            -- Override GetEntityVelocity to simulate high speed
            _G._originalGetEntityVelocity = GetEntityVelocity
            _G.GetEntityVelocity = function() return 100.0, 100.0, 100.0 end
        end,
        run = function()
            -- Force velocity check
            if eventHandlers["NexusGuard:VelocityCheck"] then
                eventHandlers["NexusGuard:VelocityCheck"]()
            else
                -- Try to trigger detection through the main detection function
                TriggerEvent("NexusGuard:DetectSpeedHack")
            end
            
            -- Wait for detection to process
            Citizen.Wait(100)
            
            -- Check if detection was logged
            local detected = false
            for _, detection in ipairs(testResults.detections or {}) do
                if detection.type == "speed_hack" or detection.type == "speedhack" then
                    detected = true
                    break
                end
            end
            
            return detected, "Speed hack was " .. (detected and "detected" or "not detected")
        end,
        teardown = function()
            -- Restore original function
            if _G._originalGetEntityVelocity then
                _G.GetEntityVelocity = _G._originalGetEntityVelocity
            end
        end,
        expectation = true -- We expect this to be detected
    },
    {
        name = "God mode detection",
        description = "Tests if the anti-cheat can detect god mode",
        setup = function()
            -- Override functions to simulate god mode
            _G._originalGetPlayerInvincible = GetPlayerInvincible
            _G._originalGetEntityHealth = GetEntityHealth
            _G._originalGetPedMaxHealth = GetPedMaxHealth
            
            _G.GetPlayerInvincible = function() return true end
            _G.GetEntityHealth = function() return 10000 end
            _G.GetPedMaxHealth = function() return 100 end
        end,
        run = function()
            -- Force god mode check
            if eventHandlers["NexusGuard:HealthCheck"] then
                eventHandlers["NexusGuard:HealthCheck"]()
            else
                -- Try to trigger through main detection function
                TriggerEvent("NexusGuard:DetectGodMode")
            end
            
            -- Wait for detection to process
            Citizen.Wait(100)
            
            -- Check if detection was logged
            local detected = false
            for _, detection in ipairs(testResults.detections or {}) do
                if detection.type == "god_mode" or detection.type == "godmode" then
                    detected = true
                    break
                end
            end
            
            return detected, "God mode was " .. (detected and "detected" or "not detected")
        end,
        teardown = function()
            -- Restore original functions
            if _G._originalGetPlayerInvincible then
                _G.GetPlayerInvincible = _G._originalGetPlayerInvincible
            end
            if _G._originalGetEntityHealth then
                _G.GetEntityHealth = _G._originalGetEntityHealth
            end
            if _G._originalGetPedMaxHealth then
                _G.GetPedMaxHealth = _G._originalGetPedMaxHealth
            end
        end,
        expectation = true
    },
    {
        name = "Weapon modification detection",
        description = "Tests if the anti-cheat can detect weapon modifications",
        setup = function()
            -- Override functions to simulate modified weapons
            _G._originalGetWeaponDamage = GetWeaponDamage
            _G._originalGetWeaponClipSize = GetWeaponClipSize
            _G._originalGetSelectedPedWeapon = GetSelectedPedWeapon
            
            _G.GetWeaponDamage = function() return 1000.0 end
            _G.GetWeaponClipSize = function() return 999 end
            _G.GetSelectedPedWeapon = function() return 1627465347 end -- WEAPON_GUSENBERG
        end,
        run = function()
            -- Force weapon check
            if eventHandlers["NexusGuard:WeaponCheck"] then
                eventHandlers["NexusGuard:WeaponCheck"]()
            else
                -- Try to trigger through main detection
                TriggerEvent("NexusGuard:DetectWeaponModification")
            end
            
            -- Wait for detection to process
            Citizen.Wait(100)
            
            -- Check if detection was logged
            local detected = false
            for _, detection in ipairs(testResults.detections or {}) do
                if detection.type == "weapon_mod" or detection.type == "weaponmod" then
                    detected = true
                    break
                end
            end
            
            return detected, "Weapon modification was " .. (detected and "detected" or "not detected")
        end,
        teardown = function()
            -- Restore original functions
            if _G._originalGetWeaponDamage then
                _G.GetWeaponDamage = _G._originalGetWeaponDamage
            end
            if _G._originalGetWeaponClipSize then
                _G.GetWeaponClipSize = _G._originalGetWeaponClipSize
            end
            if _G._originalGetSelectedPedWeapon then
                _G.GetSelectedPedWeapon = _G._originalGetSelectedPedWeapon
            end
        end,
        expectation = true
    }
}

-- Function to run a specific test case
function RunTestCase(index)
    local testCase = testCases[index]
    if not testCase then
        print("❌ Test case not found: " .. index)
        return false
    end
    
    print("🧪 Running test case: " .. testCase.name)
    
    -- Setup test environment
    if testCase.setup then 
        DEBUG.runStep("Setup for " .. testCase.name, testCase.setup)
    end
    
    -- Run the test
    local result, message = DEBUG.runStep("Execute " .. testCase.name, function()
        return testCase.run()
    end)
    
    -- Cleanup
    if testCase.teardown then
        DEBUG.runStep("Teardown for " .. testCase.name, testCase.teardown) 
    end
    
    -- Log result
    local passed = (result == testCase.expectation)
    DEBUG.logResult(testCase.name, passed, message or "No details provided")
    
    print((passed and "✅" or "❌") .. " Test case completed: " .. testCase.name .. 
          (message and " - " .. message or ""))
    
    return passed
end

-- Function to run all test cases
function RunAllTestCases()
    local totalTests = #testCases
    local passedTests = 0
    
    for i, _ in ipairs(testCases) do
        if RunTestCase(i) then
            passedTests = passedTests + 1
        end
    end
    
    print("📊 All tests completed: " .. passedTests .. "/" .. totalTests .. " passed")
    return passedTests, totalTests
end

-- Return test cases for use elsewhere
return testCases