local testCases = {
    {
        name = "Speed hack detection",
        setup = function()
            -- Override GetEntityVelocity to simulate high speed
            _G._originalGetEntityVelocity = GetEntityVelocity
            _G.GetEntityVelocity = function() return 100.0, 100.0, 100.0 end
        },
        teardown = function()
            -- Restore original function
            _G.GetEntityVelocity = _G._originalGetEntityVelocity
        },
        run = function()
            -- Force velocity check
            if eventHandlers["NexusGuard:VelocityCheck"] then
                eventHandlers["NexusGuard:VelocityCheck"]()
            end
        }
    },
    -- Add more test cases here
}

function RunTestCase(index)
    local testCase = testCases[index]
    if not testCase then
        print("❌ Test case not found: " .. index)
        return
    end
    
    print("🔍 Running test case: " .. testCase.name)
    
    -- Setup test environment
    if testCase.setup then testCase.setup() end
    
    -- Run the test
    testCase.run()
    
    -- Cleanup
    if testCase.teardown then testCase.teardown() end
    
    print("✅ Test case completed: " .. testCase.name)
end