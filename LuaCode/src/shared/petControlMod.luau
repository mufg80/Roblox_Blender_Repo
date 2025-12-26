--!strict

local Players = game:GetService("Players")

local utilMod = require(script.Parent.utilMod)
local pathMod = require(script.Parent.pathMod)
local statsMod = require(script.Parent.statsMod)

local petControlMod = {}

function petControlMod.Setup(model: Model): table
    if not model then warn("Should not reach me.") return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then
        warn("[petControlMod] Missing Humanoid or HRP on", model.Name)
        return {}
    end

    -- State
    local currentOwnerId: number | string | nil = nil
    local petAttack: boolean = true
    local petFollow: boolean = true
    local petTakeLith: boolean = false
    local petDefendlith: boolean = false
    local lithTakePosition: Vector3? = nil
    local lithDefendPosition: Vector3? = nil
    local spawnPoint: Vector3? = hrp.Position or nil
    local connections: { RBXScriptConnection } = {}

    -- Billboard (cached)
    local billboard: BillboardGui? = nil

    -- Helper: Ensure billboard exists and return it
    local function getOrCreateBillboard(): BillboardGui?
        if billboard then
            return billboard
        end

        billboard = model:FindFirstChild("BillBoardGUI")
        if billboard then
            return billboard
        end

        -- Clone from ServerStorage if missing
        local template = game.ServerStorage:FindFirstChild("BillBoards") and game.ServerStorage.BillBoards:FindFirstChild("BillBoardGUI")
        if template then
            billboard = template:Clone()
            billboard.Parent = model
            return billboard
        end

        return nil
    end

    -- Helper: Update name label
    local function updateNameLabel()
        local bb = getOrCreateBillboard()
        if not bb then
            return
        end

        local frame = bb:FindFirstChild("Frame")
        if not frame then
            return
        end

        local nameLabel: TextLabel = frame:FindFirstChild("AANameLabel")
        if not nameLabel then
            return
        end

        local mobName = statsMod.creatureStats[utilMod.customTrim(model.Name)].printedName or model.Name

        if currentOwnerId and typeof(currentOwnerId) == "number" then
            local ownerPlayer = Players:GetPlayerByUserId(currentOwnerId)
            if ownerPlayer then
                nameLabel.Text = ownerPlayer.Name .. "'s " .. mobName
                return
            end
        end

        nameLabel.Text = mobName
    end

    -- Helper: Update health bar fill
    local function updateHealthBar()
        local bb = getOrCreateBillboard()
        if not bb then
            return
        end

        local frame = bb:FindFirstChild("Frame")
        if not frame then
            return
        end

        local container = frame:FindFirstChild("PetFrameContainer")
        if not container then
            return
        end

        local bar = container:FindFirstChild("PetMeterBar")
        if not bar then
            return
        end

        local inner: Frame = bar:FindFirstChild("InnerFill")
        if not inner then
            return
        end

        local fraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
        inner.Size = UDim2.new(fraction, 0, 1, 0)
    end

    local function updateManaBar()
        if not utilMod.IsMobHealer(model) then
            return
        end
        local bb = getOrCreateBillboard()
        if not bb then
            return
        end

        local frame = bb:FindFirstChild("Frame")
        if not frame then
            return
        end

        local container = frame:FindFirstChild("PetFrameContainer")
        if not container then
            return
        end

        local mbar = container:FindFirstChild("ZPetManaMeterBar")
        if not mbar then
            return
        end

        local minner: Frame = mbar:FindFirstChild("MInnerFill")
        if not minner then
            return
        end

        mbar.Visible = true
        minner.Visible = true
        local mana = utilMod.GetAttribute(model, "Mana") or 0
        local maxmana = utilMod.GetAttribute(model, "MaxMana") or 1
        local mFraction = math.clamp(mana / maxmana, 0, 1)
        minner.Size = UDim2.new(mFraction, 0, 1, 0)
    end
    updateManaBar()

    model:GetAttributeChangedSignal("Mana"):Connect(updateManaBar)
    model:GetAttributeChangedSignal("MaxMana"):Connect(updateManaBar)

    -- Initial billboard setup
    updateNameLabel()
    updateHealthBar()

    -- === DAMAGE → HEALTH BAR UPDATE ===
    humanoid.HealthChanged:Connect(function(health: number)
        updateHealthBar()
        if health < 2 then
            utilMod.SetFlagsForDeath(model)
        end
    end)

    -- Optional: also update on MaxHealth change (e.g., buffs)
    humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        updateHealthBar()
    end)

    -- Helper: Disconnect all owner-specific connections
    local function disconnectOwnerConnections()
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        table.clear(connections)
    end

    -- Helper: Connect to a new owner
    local function connectToOwner(ownerId: number)
        local player = Players:GetPlayerByUserId(ownerId)
        if not player then
            return
        end

        petAttack = utilMod.GetAttribute(player, "PetAttack") == true
        petFollow = utilMod.GetAttribute(player, "PetFollow") == true
        petTakeLith = utilMod.GetAttribute(player, "PetTakeLith") == true
        petDefendlith = utilMod.GetAttribute(player, "PetDefendLith") == true

        if petTakeLith then
            lithTakePosition = pathMod.GetTakeLithLoc(model, hrp)
        else
            lithTakePosition = nil
        end

        if petDefendlith then
            lithDefendPosition = pathMod.GetDefendLithLoc(model, hrp)
        else
            lithDefendPosition = nil
        end

        table.insert(
            connections,
            player:GetAttributeChangedSignal("PetAttack"):Connect(function()
                petAttack = utilMod.GetAttribute(player, "PetAttack") == true
            end)
        )

        table.insert(
            connections,
            player:GetAttributeChangedSignal("PetFollow"):Connect(function()
                petFollow = utilMod.GetAttribute(player, "PetFollow") == true
                if not utilMod.GetAttribute(player, "PetFollow") then
                    spawnPoint = hrp.Position
                end
            end)
        )

        table.insert(
            connections,
            player:GetAttributeChangedSignal("PetTakeLith"):Connect(function()
                petTakeLith = utilMod.GetAttribute(player, "PetTakeLith") == true
                lithTakePosition = petTakeLith and pathMod.GetTakeLithLoc(model, hrp) or nil
            end)
        )

        table.insert(
            connections,
            player:GetAttributeChangedSignal("PetDefendLith"):Connect(function()
                petDefendlith = utilMod.GetAttribute(player, "PetDefendLith") == true
                lithDefendPosition = petDefendlith and pathMod.GetDefendLithLoc(model, hrp) or nil
            end)
        )

        updateNameLabel()
    end

    -- Handle OwnedBy changes
    local function onOwnerChanged()
        local newOwnerIdRaw = utilMod.GetAttribute(model, "OwnedBy")
        local newOwnerId: number? = nil

        if typeof(newOwnerIdRaw) == "string" then
            newOwnerId = tonumber(newOwnerIdRaw)
        elseif typeof(newOwnerIdRaw) == "number" then
            newOwnerId = newOwnerIdRaw
        end

        if currentOwnerId ~= newOwnerId then
            disconnectOwnerConnections()
            currentOwnerId = nil
            lithTakePosition = nil
            lithDefendPosition = nil
            petAttack = true
            petFollow = true
            petTakeLith = false
            petDefendlith = false
        end

        if newOwnerId then
            currentOwnerId = newOwnerId
            connectToOwner(newOwnerId)
        end

        updateNameLabel()
    end

    onOwnerChanged()
    table.insert(connections, model:GetAttributeChangedSignal("OwnedBy"):Connect(onOwnerChanged))

    -- Owner leaves game → recycle pet
    table.insert(
        connections,
        Players.PlayerRemoving:Connect(function(leavingPlayer)
            if leavingPlayer.UserId == currentOwnerId then
                utilMod.SetAttribute(model, "RecycleMe", true)
            end
        end)
    )

    -- Public API
    return {
        IsAttackEnabled = function()
            return petAttack
        end,
        IsFollowEnabled = function()
            return petFollow
        end,
        IsTakeLithEnabled = function()
            return petTakeLith
        end,
        IsDefendLithEnabled = function()
            return petDefendlith
        end,

        GetLithTakePosition = function()
            return lithTakePosition
        end,
        GetLithDefendPosition = function()
            return lithDefendPosition
        end,
        GetSpawnPoint = function()
            return spawnPoint
        end,

        Refresh = onOwnerChanged,

        GetOwnerModel = function()
            if not currentOwnerId or typeof(currentOwnerId) ~= "number" then
                return nil
            end
            local player = Players:GetPlayerByUserId(currentOwnerId)
            return player and player.Character
        end,
    }
end

return petControlMod