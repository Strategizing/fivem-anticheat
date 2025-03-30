-- Security module for NexusGuard
Security = {
    tokens = {},
    secretKey = GetRandomString(32), -- Generate a random key each server start
    clientHashes = {}
}

-- Generate a security token for a player
function Security.GenerateToken(playerId)
    if not playerId then return nil end
    
    local token = {
        id = GetRandomString(24),
        timestamp = os.time(),
        playerHash = GetPlayerHash(playerId)
    }
    
    -- Store token
    Security.tokens[playerId] = token
    
    -- Return token id to client
    return token.id
end

-- Validate a security token
function Security.ValidateToken(playerId, tokenId)
    if not playerId or not tokenId then return false end
    
    local token = Security.tokens[playerId]
    if not token then return false end
    
    -- Check if token matches and isn't expired
    if token.id == tokenId and (os.time() - token.timestamp) < 3600 then
        -- Refresh token timestamp
        token.timestamp = os.time()
        return true
    end
    
    return false
end

-- Store client hash for validation
function Security.RegisterClientHash(playerId, clientHash)
    Security.clientHashes[playerId] = clientHash
end

-- Validate client hash
function Security.ValidateClientHash(playerId, clientHash)
    -- If we haven't recorded a hash yet, this is the first registration
    if not Security.clientHashes[playerId] then
        Security.RegisterClientHash(playerId, clientHash)
        return true
    end
    
    -- Otherwise, verify it matches the stored hash
    return Security.clientHashes[playerId] == clientHash
end

-- Helper function to generate random string
function GetRandomString(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    math.randomseed(os.time())
    for i = 1, length do
        local randomChar = math.random(1, #charset)
        result = result .. string.sub(charset, randomChar, randomChar)
    end
    return result
end

-- Helper function to create a unique player hash
function GetPlayerHash(playerId)
    local identifiers = GetPlayerIdentifiers(playerId) or {}
    local idsStr = table.concat(identifiers, "")
    return GetHashKey(idsStr .. playerId)
end

return Security
