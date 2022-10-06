local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HTTPService = game:GetService("HttpService")

local ACFolder = ReplicatedStorage:WaitForChild("ACEvents")
local AntiServer = ACFolder:WaitForChild("ACMain")
local eTech = ReplicatedStorage:WaitForChild("eTech")
local eRemotes = eTech:WaitForChild("Remotes")
local ExemptRemote = ACFolder:WaitForChild("ExemptToggle")

local Cmdr = require(ReplicatedStorage:WaitForChild("Cmdr"))
print(Cmdr)

local activePlayers = {}
local characterConnections = {}
local remoteList = {}
local altHats = {
    "Brown Charmer Hair",
    "Pal Hair",
    "Casey's Hair",
    "Straight Blonde Hair",
    "Lavender Updo",
    "Black Ponytail",
    "Brown Hair",
    "Down to Earth Hair",
    "Chestnut Bun",
    "True Blue Hair",
    "Red Roblox Cap",
    "ROBLOX 'R' Baseball Cap"
}

local confirmationTime = 60 -- time to wait before kicking the player if not confirmed (not reccomended to be below 30 seconds)
local minimumRank = 0 -- minimum rank to be exempt from the anti-cheat
local exemptGroupId = 4904885 -- group id to check for exemption

-- settings for anti-fling
local maxAngularVelocity = 1000 -- maximum speed a player can spin

-- settings for anti-ddos
local antiDDOS = true -- if true, will check if every remote in the game has large amounts of data being sent

local dataLimit = false -- if this is true and antiDDOS is true, will kick the player if they send more than a specified amount of data per remote (this is instead of maxSizes)
local generalDataLimit = 1000 -- max amount of data that can be sent per remote (in bytes)

local maxStringSize = 1000 -- max size of a string that can be sent to the server
local maxTableSize = 1000 -- max size of a table that can be sent to the server
local maxIntegerSize = 1000 -- max size of an integer that can be sent to the server

local maxRemotesPerTime = 500 -- max amount of remotes that can be fired in a specified time
local maxRemoteTime = 1 -- time to wait before resetting the remote count

-- settings for anti-teleport
local maxPositionWarnings = 20 -- max amount of times a player can be warned for moving too far in one frame
local maxTPDistance = 100 -- max distance a player can teleport in one frame (no warnings)
local maxMoveDistance = 1 -- max distance a player can move in one frame with warnings

local remoteWaitTime = 5 -- time to wait before adding all remotes in game to the remote list

-- settings for anti gun mod
local maxBulletSpeed = 5000 -- max bullet speed for projectiles (this setting is here because there are issues with checking the gun's speed externally based on the tool)

-- the following settings are for the anti-alt
local minFriends = 5 -- if a player has less than this amount of friends, they will be considered an alt


local reportReasons = {
    ["FLY"] = "flying",
    ["HBE"] = "hitbox modification",
    ["TP"] = "teleport hacking",
    ["SP"] = "speed hacking",
    ["JUMP"] = "jump hacking",
    ["NOCOLLIDE"] = "nocollide hacking",
    ["NAMETAG"] = "removing their nametag",
    ["PS"] = "platform standing state",
    ["GUNMOD"] = "gun modification",
    ["LONGSTRING"] = "sending a long string",
    ["BIGTABLE"] = "sending a large table",
    ["BIGINT"] = "sending a large integer",
    ["BIGVECTOR"] = "sending a large vector",
    ["DDOS"] = "DDOSing the server",
    ["FLING"] = "flinging",
    ["NOTRACE"] = "error with no tracable script",
    ["DATA"] = "fired remote with args too large",
    ["GRAV"] = "modifying gravity",
    ["HUM"] = "removal of humanoid",
    ["FLOAT"] = "floating (platform standing)", -- not to be confused with the humanoid platformstanding state
    ["ALT"] = "alternate account"
}

local function sendWebhook(data)
    local encoded = HTTPService:JSONEncode(data)
    local success, response = pcall(function()
        return HTTPService:PostAsync("https://hooks.hyra.io/api/webhooks/1023621007757545588/vFSKiexNynf9VksDRv2StoHUBak7v-0D9H718-Hs6cXgTIXdDw5HYuWVW0IkUQtKk9go", encoded)
    end)
    print(success, response)
end

local function reportPlayer(player, reason)
    local imageLink = "https://www.roblox.com/headshot-thumbnail/image?userId="..tostring(player.UserId).."&width=150&height=150&format=png"
    local data = {
        ["username"] = "OVERWATCH",
        ["avatar_url"] = "https://cdn.discordapp.com/attachments/522409606933118978/1023623275974234142/Wasteland_Scanner_logo.png",
        ["embeds"] = {{
            ["title"] = "PROFILE",
            ["url"] = "https://www.roblox.com/users/" .. tostring(player.UserId) .. "/profile",
            ["thumbnail"] = {
                ["url"] = imageLink
            },
            ["description"] = player.Name .. " has triggered the anticheat",
            ["color"] = 16711680,
            ["fields"] = {
				{
					["name"] = "NAME",
                    ["value"] = player.Name .. " (" .. tostring(player.UserId) .. ")",
					["inline"] = false
				},
				{
					["name"] = "REASON",
                    ["value"] = reason,
                    ["inline"] = false;
				}
			},
            ["footer"] = {
				["text"] = "OVERWATCH ANTICHEAT";
			}
        }}
    }
    sendWebhook(data)
end

local function exemptPlayer(player, bool)
    if activePlayers[player] then
        activePlayers[player].exempt = bool
    end
end

local function checkExemption(data)
    if (data.exempt or data.whitelisted) then
        return true
    else
        return false
    end
end

local function kickPlayer(player, reason)
    player:Kick(reason)
    exemptPlayer(player, true)
end

local function onCharacterAdded(player, character)
    local diedConnection

    exemptPlayer(player, false)

    activePlayers[player].lastPosition = character:WaitForChild("HumanoidRootPart").Position
    diedConnection = character:WaitForChild("Humanoid").Died:Connect(function()
        exemptPlayer(player, true)
        diedConnection:Disconnect()
    end)
end

local function hasAltHats(userid)
    local success, hats = pcall(function()
        return game.Players:GetCharacterAppearanceInfoAsync(userid)
    end)
    if success then
        if #hats.assets == 0 then
            return true
        end
        for _, hat in pairs(hats.assets) do
            if table.find(altHats, hat.name) then
                return true
            end
        end
    else
        task.wait(1)
        return hasAltHats(userid)
    end
    return false
end

local function checkFriends(userid)
    local success, other = pcall(function()
        return game.Players:GetFriendsAsync(userid) 
    end)
    if success then
        if #other:GetCurrentPage() < minFriends then
            return true
        end
    else
        task.wait(1)
        return checkFriends(userid)
    end
end

local function checkAltName(player, checkString)
    local matchedString = string.match(checkString, "^%u%l+%u%l+%d$")
    local matchedString2 = string.match(checkString, "^%u%l+%u%l+%d%d$")
    if matchedString then
        if hasAltHats(player.userId) and checkFriends(player.userId) then
            return true
        end
    elseif matchedString2 then
        if hasAltHats(player.userId) and checkFriends(player.userId) then
            return true
        end
    end
    return false
end

local function teleportChecks()
    for player, data in pairs(activePlayers) do

        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if data and (checkExemption(data) or player:FindFirstChild("TP_A")) then 
                data.lastPosition = player.Character.HumanoidRootPart.Position
                return 
            end

            if data.positionWarnings >= maxPositionWarnings then
                kickPlayer(player, reportReasons["SP"])
                reportPlayer(player, reportReasons["SP"])
                return
            end
            local position = player.Character.HumanoidRootPart.Position
            local distance = Vector3.new(position.X, 0, position.Z) - Vector3.new(data.lastPosition.X, 0, data.lastPosition.Z)
            if distance.Magnitude > maxMoveDistance then
                data.positionWarnings = data.positionWarnings + 1
            else
                data.positionWarnings = 0
            end
            if distance.Magnitude > maxTPDistance then
                kickPlayer(player, reportReasons["TP"])
                reportPlayer(player, reportReasons["TP"])
                return
            end
            data.lastPosition = position
        end
    end
end


local function flingChecks()
    for player, data in pairs(activePlayers) do
        if data and checkExemption(data) then return end -- if the player is exempt, don't check them

        if player.Character and player.Character:FindFirstChild("UpperTorso") then
            local torso = player.Character.UpperTorso
            if torso.RotVelocity.Magnitude > maxAngularVelocity then
                kickPlayer(player, reportReasons["FLING"])
                reportPlayer(player, reportReasons["FLING"])
            end
        end
    end
end

local function checkTableSizeRecursive(tbl)
    local size = 0
    local overStringSize = false
    local overNumberSize = false
    local overTableSize = false
    for _, v in pairs(tbl) do
        if typeof(v) == "table" then
            local recursiveSize = checkTableSizeRecursive(v)
            size = size + recursiveSize[2]
            if recursiveSize[1] then
                overTableSize = true
            end
        elseif typeof(v) == "string" then
            if string.len(v) > maxStringSize then
                overStringSize = true
            end
        elseif typeof(v) == "number" then
            if v > maxIntegerSize then
                overNumberSize = true
            end
        end
    end
    size += #tbl
    if size > maxTableSize then
        overTableSize = true
    end
    return {overTableSize or overStringSize or overNumberSize, size}
end

if antiDDOS then
    task.spawn(function()
        task.wait(remoteWaitTime)

        for _, remote in pairs(game:GetDescendants()) do
            if remote:IsA("RemoteEvent") then
                table.insert(remoteList, remote)
            end
        end
    end)
end

AntiServer.OnServerEvent:Connect(function(player, data)
    if activePlayers[player] and checkExemption(activePlayers[player]) then return end

    if reportReasons[data] then
        kickPlayer(player, reportReasons[data])
        reportPlayer(player, reportReasons[data])
    else
        kickPlayer(player, "You have been kicked for unknown reason")
        reportPlayer(player, "unknown reason")
    end
end)

ExemptRemote.Event:Connect(function(player, bool)
    exemptPlayer(player, bool)
end)

ACFolder:WaitForChild("Confirmation").OnServerEvent:Connect(function(player)
    if activePlayers[player] then
        activePlayers[player].confirmed = true
    end
end)

ACFolder:WaitForChild("UpdatePosition").Event:Connect(function(player, position)
    if activePlayers[player] then
        activePlayers[player].lastPosition = position
    end
end)

Players.PlayerAdded:Connect(function(player)
    if checkAltName(player, player.Name) then
        kickPlayer(player, reportReasons["ALT"])
        reportPlayer(player, reportReasons["ALT"])
        return
    end
    repeat wait() until player.Parent == Players and player.Character and #remoteList > 0


    activePlayers[player] = {
        lastPosition = player.Character:WaitForChild("HumanoidRootPart").Position,
        positionWarnings = 0,
        lastWarnings = -math.huge,
        exempt = false,
        confirmed = false,
        sessionId = HTTPService:GenerateGUID(false),
        whitelisted = false
    }

    if player:GetRankInGroup(exemptGroupId) >= minimumRank then 
        activePlayers[player].whitelisted = true
    end

    for _, remote in pairs(remoteList) do
        activePlayers[player][remote] = {
            count = 0,
            maxTime = -math.huge
        }
    end
    
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)

    local startingId = activePlayers[player].sessionId
    task.spawn(function()
        task.wait(confirmationTime)
        if activePlayers[player] and activePlayers[player].sessionId == startingId and not activePlayers[player].confirmed then
            kickPlayer(player, "You have been kicked for not confirming")
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    activePlayers[player] = nil
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end
end)


RunService.Heartbeat:Connect(function()
    teleportChecks()
    flingChecks()
end)

eRemotes.ProjectileReplicate.OnServerEvent:Connect(function(player, id, origin, dir, speed, nilBit, acceleration, gravity, boltOrColor, ignore, ptime)

    if activePlayers[player] and checkExemption(activePlayers[player]) then return end

    if player.Character and player.Character:FindFirstChild("BlasterSettings", true) then
        local blasterSettings = player.Character:FindFirstChild("BlasterSettings", true)
        local serverColor = blasterSettings.Parent.Emitter.Color

        if typeof(boltOrColor) == "Color3" and boltOrColor ~= serverColor then
            kickPlayer(player, reportReasons["GUNMOD"])
            reportPlayer(player, reportReasons["GUNMOD"])
        elseif gravity ~= nil and blasterSettings.Stats.Gravity.Value ~= gravity then
            kickPlayer(player, reportReasons["GUNMOD"])
            reportPlayer(player, reportReasons["GUNMOD"])
        elseif speed ~= nil and speed > maxBulletSpeed then
            kickPlayer(player, reportReasons["GUNMOD"])
            reportPlayer(player, reportReasons["GUNMOD"])
        end


    end
end)

if antiDDOS then
    for _, remote in pairs(remoteList) do
        remote.OnServerEvent:Connect(function(player, ...)
            if activePlayers[player] and checkExemption(activePlayers[player]) then return end

            if not activePlayers[player][remote] then
                activePlayers[player][remote] = {
                    count = 0,
                    maxTime = -math.huge
                }
            end

            local currentTime = tick()
            local lastFired = activePlayers[player][remote].maxTime
            local timesFired = activePlayers[player][remote].count

            local args = {...}

            if dataLimit then
                if #HTTPService:JSONEncode(args) > generalDataLimit then
                    kickPlayer(player, reportReasons["DATA"])
                    reportPlayer(player, reportReasons["DATA"].. " in remote " .. remote.Name .. " with size " .. #HTTPService:JSONEncode(args))
                end
            else
                for _, arg in pairs(args) do
                    if typeof(arg) == "string" then
                        if string.len(arg) > maxStringSize then
                            kickPlayer(player, reportReasons["LONGSTRING"])
                            reportPlayer(player, reportReasons["LONGSTRING"] .. " in remote " .. remote.Name)
                            return
                        end
                    elseif typeof(arg) == "table" then
                        if checkTableSizeRecursive(arg)[1] then
                            kickPlayer(player, reportReasons["BIGTABLE"])
                            reportPlayer(player, reportReasons["BIGTABLE"] .. " in remote " .. remote.Name)
                            return
                        end
                    elseif typeof(arg) == "number" then
                        if arg > maxIntegerSize then
                            kickPlayer(player, reportReasons["BIGINT"])
                            reportPlayer(player, reportReasons["BIGINT"] .. " in remote " .. remote.Name)
                            return
                        end
                    end
                end
                if currentTime - lastFired < maxRemoteTime then
                    if timesFired > maxRemotesPerTime then
                        kickPlayer(player, reportReasons["DDOS"])
                        reportPlayer(player, reportReasons["DDOS"] .. " in remote " .. remote.Name)
                        return
                    else
                        activePlayers[player][remote].count += 1
                    end
                else
                    activePlayers[player][remote].maxTime = currentTime
                    activePlayers[player][remote].count = 1
                end
            end
        end)
    end
end