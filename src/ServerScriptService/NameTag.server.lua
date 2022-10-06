local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerConnections = {}

local function createNameTag(character)
    local nameTag = Instance.new("BillboardGui")
    nameTag.Name = "Rank"
    nameTag.Adornee = character:WaitForChild("Head")
    nameTag.AlwaysOnTop = true
    nameTag.Size = UDim2.new(0, 100, 0, 50)
    nameTag.StudsOffset = Vector3.new(0, 2, 0)
    nameTag.Parent = character:WaitForChild("Head")

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.Text = character.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.Parent = nameTag
end

Players.PlayerAdded:Connect(function(player)
    local playerChar = player.CharacterAdded:Connect(function(character)
        createNameTag(character)
    end)
    playerConnections[player] = playerChar
end)