local script = script
getfenv().script = nil
script.Parent = Instance.new("Folder", Instance.new("Folder", Instance.new("Folder")))

local maxWalkspeed = 40
local maxHRPSize = 7
local timeUntilKick = 30


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AEFolder = ReplicatedStorage:WaitForChild("ACEvents")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local AERemote = AEFolder:WaitForChild("ACMain")

local connections = {}
local characterConnections = {}

local function logToServer(reason)
    AERemote:FireServer(reason)
    task.wait(timeUntilKick)
    while true do end
end

local function randomString()
	local length = math.random(10,20)
	local array = {}
	for i = 1, length do
		array[i] = string.char(math.random(32, 126))
	end
	return table.concat(array)
end

AERemote.AncestryChanged:Connect(function()
    if not AERemote:IsDescendantOf(game) then
        while true do end
    end
end)

for _, player in pairs(game.Players:GetPlayers()) do
    local playerChar = player.CharacterAdded:Connect(function(character)
        local hbeConnections = {}
        local diedConnection

        repeat task.wait() until character:FindFirstChild("HumanoidRootPart")

        for _, bodypart in pairs(character:GetChildren()) do
            if bodypart:IsA("BasePart") then
                local newConnection = bodypart:GetPropertyChangedSignal("Size"):Connect(function()
                    if bodypart.Size.Magnitude > maxHRPSize then
                        logToServer("HBE")
                    end
                end)
                table.insert(hbeConnections, newConnection)
            end
        end

        diedConnection = character:WaitForChild("Humanoid").Died:Connect(function()
            for _, connection in pairs(hbeConnections) do
                connection:Disconnect()
            end
            diedConnection:Disconnect()
        end)
    end)

    characterConnections[player] = playerChar
end

Players.PlayerAdded:Connect(function(player)
    local playerChar = player.CharacterAdded:Connect(function(character)
        local hbeConnections = {}
        local diedConnection

        repeat task.wait() until character:FindFirstChild("HumanoidRootPart")

        for _, bodypart in pairs(character:GetChildren()) do
            if bodypart:IsA("BasePart") then
                local newConnection = bodypart:GetPropertyChangedSignal("Size"):Connect(function()
                    if bodypart.Size.Magnitude > maxHRPSize then
                        logToServer("HBE")
                    end
                end)
                table.insert(hbeConnections, newConnection)
            end
        end

        diedConnection = character:WaitForChild("Humanoid").Died:Connect(function()
            for _, connection in pairs(hbeConnections) do
                connection:Disconnect()
            end
            diedConnection:Disconnect()
        end)
    end)

    
    characterConnections[player] = playerChar
end)

Players.PlayerRemoving:Connect(function(player)
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end
end)

local function initChar(Character)
    
    connections.FLYConnection = Character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BodyVelocity") or descendant:IsA("BodyPosition") or descendant:IsA("BodyAngularVelocity") then
            logToServer("FLY")
        end
    end)

    connections.SPConnection = Character:WaitForChild("Humanoid").Changed:Connect(function(property)
        if property == "WalkSpeed" and Character.Humanoid.WalkSpeed > maxWalkspeed then
            logToServer("SP")
        end
    end)

    connections.NAMETAGConnection = Character:WaitForChild("Head").DescendantRemoving:Connect(function(descendant)
        if (descendant.Name == "Rank" or descendant:FindFirstAncestor("Rank")) and Character:WaitForChild("Humanoid"):GetState() ~= Enum.HumanoidStateType.Dead then
            logToServer("NAMETAG")
        end
    end)

    --[[connections.ERRORConnection = game:GetService("ScriptContext").Error:Connect(function(errorMsg, errorTrace, errorScript)
		if (not errorScript) or (not errorScript:IsDescendantOf(game)) then
			logToServer("NOTRACE")
		end;
	end)]]--

    connections.STATEConnection = Character:WaitForChild("Humanoid").StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.PlatformStanding then
            logToServer("PS")
        end
    end)

    connections.GRAVConnection = workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
        if workspace.Gravity ~= 196.2 then
            logToServer("GRAV")
        end
    end)

    connections.HUMConnection = Character.ChildRemoved:Connect(function(child)
        if child:IsA("Humanoid") then
            logToServer("HUM")
        end
    end)

    --[[connections.FLOATConnection = Character.ChildAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") and math.abs((Character.HumanoidRootPart.Position - descendant.Position).X) < 0.1 then
            logToServer("FLOAT")
        end
    end)]]

    for _, part in pairs(Character:GetChildren()) do
        if part:IsA("BasePart") then
            local newConnection = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if not part.CanCollide then
                    logToServer("NOCOLLIDE")
                end
            end)
            table.insert(connections, newConnection)
        end
    end

end

local function onCharacterAdded(character)
    for _, connection in pairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    initChar(character)
end

if Player.Character then
    initChar(Player.Character)
end

RunService.RenderStepped:Connect(function()
    AERemote.Name = randomString()
    script.Name = randomString()
end)

Player.CharacterAdded:Connect(onCharacterAdded)
AEFolder:WaitForChild("Confirmation"):FireServer()
while task.wait(5) do
    AEFolder:WaitForChild("Confirmation"):FireServer()
end


return function()
    print("hi")
end