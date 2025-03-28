-- Script to verify and setup luasocket for debugging
print("Checking luasocket installation...")

local success, socket = pcall(require, "socket")
if not success then
    print("LuaSocket is not installed! Installing...")
    
    -- For Windows users, download and setup instructions
    print("\nPlease follow these steps to install luasocket:")
    print("1. Download LuaSocket from https://github.com/lunarmodules/luasocket/releases")
    print("2. Extract the files to: " .. package.cpath:match("[^;]+"))
    print("3. Ensure socket.dll and mime.dll are in the correct location")
    print("\nAlternatively, if using LuaRocks, run: luarocks install luasocket")
else
    print("LuaSocket is installed!")
    print("Version: " .. socket._VERSION)
    -- Fix ambiguity with parentheses
    print("Location: " .. (package.searchpath("socket.core", package.cpath) or "Unknown"))
end

-- Check if LuaPanda can be loaded
local success, panda = pcall(require, "LuaPanda")
if not success then
    print("\nLuaPanda is not correctly installed!")
    print("Make sure the LuaHelper extension is properly installed in VS Code.")
else
    print("\nLuaPanda is installed!")
end

print("\nDebugging environment details:")
print("Lua version: " .. _VERSION)
print("package.path: " .. package.path)
print("package.cpath: " .. package.cpath)
