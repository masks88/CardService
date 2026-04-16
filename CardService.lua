-- \\ Card Service : Handles Cards + Card Functions // --
-- \\ Created by : masks88 // --
-- \\ Services // --

local Chat = game:GetService("Chat")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- \\ Modules // --

local BuffService = require(ServerScriptService.Modules.BuffService)
local Effects = require(ServerScriptService.Modules.Effects)
local CardInformation = require(ReplicatedStorage.Modules.CardInformation)
local AttributeManager = require(ReplicatedStorage.Modules.AttributeManager)
local AnimationHandler = require(ReplicatedStorage.Modules.AnimationHandler)
local ActionHandler = require(ReplicatedStorage.Modules.ActionHandler)

-- \\ Variables + Misc // --

local PlayerDatas = ServerStorage:WaitForChild("PlayerData")
local Requests = ReplicatedStorage:WaitForChild("Requests")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ThoughtRequest = Requests:WaitForChild("Thought")
local Audio = Assets:WaitForChild("Audio")

local CardService = {}

local ActiveCleanups: { [Player]: { [string]: () -> () } } = {}
local TriggerCooldowns: { [Player]: { [string]: number } } = {}
local CardConnections: { [Player]: { RBXScriptConnection } } = {}

-- \\ Helpers // --

local function DisconnectConnections(Player: Player)
	local Connections = CardConnections[Player]
	if not Connections then
		return
	end

	for _, Connection in ipairs(Connections) do
		Connection:Disconnect()
	end

	CardConnections[Player] = nil
end

local function AddConnection(Player: Player, Connection: RBXScriptConnection)
	if not CardConnections[Player] then
		CardConnections[Player] = {}
	end

	table.insert(CardConnections[Player], Connection)
end

local function RunCleanups(Player: Player) -- Runs if new cards get added / removed
	local PlayerCleanups = ActiveCleanups[Player]
	if not PlayerCleanups then
		return
	end

	for _, Cleanup in pairs(PlayerCleanups) do
		Cleanup()
	end

	ActiveCleanups[Player] = {}
end

local function StoreCleanup(Player: Player, CardName: string, Cleanup: () -> ()) -- Stores for cleanup
	if not ActiveCleanups[Player] then
		ActiveCleanups[Player] = {}
	end

	ActiveCleanups[Player][CardName] = Cleanup
end

-- \\ Utility // --

local function GetClosestPlayer(Character: Model, Range: number): (Player?, Model?)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return nil, nil
	end

	local ClosestPlayer: Player? = nil
	local ClosestCharacter: Model? = nil
	local ClosestDistance = Range

	for _, TargetCharacter in ipairs(workspace.Alive:GetChildren()) do
		if TargetCharacter == Character then
			continue
		end

		local TargetRoot = TargetCharacter:FindFirstChild("HumanoidRootPart")
		if not TargetRoot then
			continue
		end

		local TargetHumanoid = TargetCharacter:FindFirstChildOfClass("Humanoid")
		if not TargetHumanoid or TargetHumanoid.Health <= 0 then
			continue
		end

		local Distance = (TargetRoot.Position - Root.Position).Magnitude
		if Distance < ClosestDistance then
			ClosestDistance = Distance
			ClosestCharacter = TargetCharacter
			ClosestPlayer = Players:GetPlayerFromCharacter(TargetCharacter)
		end
	end

	return ClosestPlayer, ClosestCharacter
end

CardService.GetClosestPlayer = GetClosestPlayer

-- \\ Card Functions // --

CardService["Starved Dog"] = function(Player: Player, Character: Model, PlayerData: Folder)
	AttributeManager.CreateAttribute(Character, "Starved Dog", true)

	return function()
		AttributeManager.RemoveAttribute(Character, "Starved Dog")
	end
end

CardService["Opportunist"] = function(Player: Player, Character: Model, PlayerData: Folder)
	AttributeManager.CreateAttribute(Character, "Opportunist", true)
end

CardService["Heavy Hitter"] = function(Player: Player, Character: Model, PlayerData: Folder)
	AttributeManager.CreateAttribute(Character, "Heavy Hitter", true)
end

CardService["Mountain Master"] = function(Player: Player, Character: Model, PlayerData: Folder)
	BuffService:StrengthScale(Player, 1, "Mountain Master")
	BuffService:DurabilityScale(Player, 1, "Mountain Master")

	return function()
		BuffService:Remove(Player, "Mountain Master")
	end
end

CardService["Penny Pincher"] = function(Player: Player, Character: Model, PlayerData: Folder)
	local MidCurrency = 2500000
	local MaxCurrency = 15000000
	local Connection: RBXScriptConnection?

	local function UpdatePennyPincher()
		local Currency = PlayerData.Currency.Value
		local Scale = 0

		if Currency >= MidCurrency then
			local Alpha = math.clamp((Currency - MidCurrency) / (MaxCurrency - MidCurrency), 0, 1)
			Scale = Alpha * 0.15
		else
			local Alpha = math.clamp((MidCurrency - Currency) / MidCurrency, 0, 1)
			Scale = -(Alpha * 0.15)
		end

		BuffService:StrengthScale(Player, Scale, "Penny Pincher")
		BuffService:TechniqueScale(Player, Scale, "Penny Pincher")
	end

	UpdatePennyPincher()

	Connection = PlayerData.Currency.Changed:Connect(function()
		if Player.Character ~= Character then
			if Connection then
				Connection:Disconnect()
				Connection = nil
			end

			return
		end

		UpdatePennyPincher()
	end)

	return function()
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		BuffService:Remove(Player, "Penny Pincher")
	end
end

CardService["Lesser Provocation"] = function(Player: Player, Character: Model, PlayerData: Folder)
	local Head = Character:FindFirstChild("Head")
	if not Head then
		return
	end

	local TargetPlayer, TargetCharacter = GetClosestPlayer(Character, 10)

	local Taunts = {
		"You fight like you were born tired..",
		"Is that really all you've got?",
		"My grandmother hits harder than you.",
		"You're an embarrassment to everyone watching.",
		"Stop. You're making this painful for both of us.",
		"I've seen better footwork from a toddler.",
		"You trained for THIS?",
		"I almost feel bad. Almost.",
		"You should've stayed home today.",
		"Keep going. I need the warm up.",
	}

	Chat:Chat(Head, Taunts[math.random(1, #Taunts)], Enum.ChatColor.White)

	if not TargetPlayer or not TargetCharacter then
		return
	end

	local TargetHead = TargetCharacter:FindFirstChild("Head")
	if not TargetHead then
		return
	end

	BuffService:StrengthScale(TargetPlayer, 0.2, "Lesser Provocation")
	BuffService:TechniqueScale(TargetPlayer, 0.2, "Lesser Provocation")
	BuffService:DurabilityScale(TargetPlayer, -0.3, "Lesser Provocation")

	Chat:Chat(TargetHead, "You are starting to piss me off..", Enum.ChatColor.White)

	task.delay(30, function()
		BuffService:Remove(TargetPlayer, "Lesser Provocation")
	end)
end

CardService["Hit Those High Notes"] = function(Player: Player, Character: Model, PlayerData: Folder)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Root or not Humanoid then
		return
	end

	AnimationHandler:PlayAnimation(Character, "Skills/Scream", 1, Enum.AnimationPriority.Action2, 0.1)
	Effects:PlaySound(Player, { SFX = Audio["Scream"], Parent = Root })

	local SelfDamage = Humanoid.MaxHealth / 40
	if Humanoid.Health - SelfDamage > 10 then
		Humanoid.Health -= SelfDamage
	end

	for _, TargetCharacter in ipairs(workspace.Alive:GetChildren()) do
		if TargetCharacter == Character or TargetCharacter.Name == Character.Name then
			continue
		end

		local TargetRoot = TargetCharacter:FindFirstChild("HumanoidRootPart")
		if not TargetRoot then
			continue
		end

		if (TargetRoot.Position - Root.Position).Magnitude > 30 then
			continue
		end

		local TargetPlayer = Players:GetPlayerFromCharacter(TargetCharacter)
		if not TargetPlayer then
			continue
		end

		Effects:PlaySound(TargetPlayer, { SFX = Audio["Scream"], Parent = Root })
		AnimationHandler:PlayAnimation(TargetCharacter, "Skills/CoverEars", 0.5, Enum.AnimationPriority.Action2, 0.1)
		ActionHandler:CreateActionStun("Stunned", TargetCharacter, 3)
	end
end

CardService["Silver Tongue"] = function(Player: Player, Character: Model, PlayerData: Folder)
	local TargetPlayer = GetClosestPlayer(Character, 10)
	if not TargetPlayer then
		return
	end

	local Thoughts = {
		"Damn he might be right..",
		"He does have a good point..",
	}

	ThoughtRequest:FireClient(TargetPlayer, Thoughts[math.random(1, #Thoughts)])
end

-- \\ Draft Cards // --

local DraftCardBuffs = {
	-- COMMON
	["Raw Power"] = { StrengthScale = 0.03 },
	["Quick Feet"] = { SpeedScale = 0.03 },
	["Thick Skin"] = { DurabilityScale = 0.03 },
	["Conditioning"] = { StaminaScale = 0.03 },
	["Muscle Memory"] = { TechniqueScale = 0.03 },
	["Steady Hands"] = { TechniqueScale = 0.02, DurabilityScale = 0.01 },
	["Light Step"] = { SpeedScale = 0.02, StaminaScale = 0.01 },
	["Grit"] = { DurabilityScale = 0.02, StrengthScale = 0.01 },
	["Deep Breath"] = { StaminaScale = 0.02, SpeedScale = 0.01 },
	["Firm Grip"] = { StrengthScale = 0.02, TechniqueScale = 0.01 },

	-- UNCOMMON
	["Heavy Hands"] = { StrengthScale = 0.05, TechniqueScale = 0.02 },
	["Reflex"] = { SpeedScale = 0.05, DurabilityScale = 0.02 },
	["Endure"] = { DurabilityScale = 0.05, StaminaScale = 0.02 },
	["Marathon"] = { StaminaScale = 0.05, SpeedScale = 0.02 },
	["Precision"] = { TechniqueScale = 0.05, StrengthScale = 0.02 },
	["Balanced"] = {
		StrengthScale = 0.02,
		SpeedScale = 0.02,
		TechniqueScale = 0.02,
		DurabilityScale = 0.02,
		StaminaScale = 0.02,
	},

	-- RARE
	["Iron Chin"] = { DurabilityScale = 0.08, StrengthScale = 0.03 },
	["Blitz"] = { SpeedScale = 0.08, StaminaScale = 0.03 },
	["Crusher"] = { StrengthScale = 0.08, TechniqueScale = 0.03 },
	["Flow State"] = { TechniqueScale = 0.08, SpeedScale = 0.03 },
	["Tireless"] = { StaminaScale = 0.08, DurabilityScale = 0.03 },

	-- EPIC
	["Well-Rounded"] = {
		StrengthScale = 0.05,
		SpeedScale = 0.05,
		TechniqueScale = 0.05,
		DurabilityScale = 0.05,
		StaminaScale = 0.05,
	},
	["Apex"] = { StrengthScale = 0.10, DurabilityScale = 0.05 },
	["Ghost"] = { SpeedScale = 0.10, TechniqueScale = 0.05 },
	["Prodigy"] = { TechniqueScale = 0.10, StrengthScale = 0.05 },
	["Fortress"] = { DurabilityScale = 0.10, StaminaScale = 0.05 },
}

-- Register the buffs
for CardName, Buffs in pairs(DraftCardBuffs) do
	if not CardService[CardName] then
		CardService[CardName] = function(Player: Player, Character: Model, PlayerData: Folder)
			for BuffType, Value in pairs(Buffs) do
				local BuffFunction = BuffService[BuffType]
				if BuffFunction then
					BuffFunction(BuffService, Player, Value, "Card_" .. CardName)
				end
			end

			return function()
				BuffService:Remove(Player, "Card_" .. CardName)
			end
		end
	end
end

-- \\ Reset // --

function CardService.ResetCards(Player: Player, Character: Model)
	RunCleanups(Player)

	local PlayerData = PlayerDatas:FindFirstChild(Player.Name)
	if not PlayerData then
		return
	end

	local Cards = PlayerData:FindFirstChild("Cards")
	if not Cards then
		return
	end

	for _, Card in ipairs(Cards:GetChildren()) do
		local CardData = CardInformation.GetData(Card.Name)
		local IsOriginalPassive = CardData and CardData.CardType == "Passive Card"
		local IsDraftCard = DraftCardBuffs[Card.Name] ~= nil

		if IsOriginalPassive or IsDraftCard then
			local CardFunction = CardService[Card.Name]
			if CardFunction then
				local Cleanup = CardFunction(Player, Character, PlayerData)
				if Cleanup then
					StoreCleanup(Player, Card.Name, Cleanup)
				end
			end
		end
	end
end

function CardService.UseCard(Player: Player, PlayerData: Folder, CardName: string)
	local Character = Player.Character
	if not Character then
		return
	end

	local Data = CardInformation.GetData(CardName)
	if not Data or Data.CardType ~= "Trigger Card" then
		warn("Invalid Card")
		return
	end

	local CardFolder = PlayerData:FindFirstChild("Cards")
	if not CardFolder then
		return
	end

	if not CardFolder:FindFirstChild(CardName) then
		return
	end

	local Cooldown = Data.Cooldown or 30
	if not TriggerCooldowns[Player] then
		TriggerCooldowns[Player] = {}
	end

	local LastUsed = TriggerCooldowns[Player][CardName]
	if LastUsed then
		local Remaining = Cooldown - (os.clock() - LastUsed)
		if Remaining > 0 then
			ThoughtRequest:FireClient(Player, "Card on cooldown: " .. math.ceil(Remaining) .. " seconds remaining")
			return
		end
	end

	local CardFunction = CardService[CardName]
	if CardFunction then
		CardFunction(Player, Character, PlayerData)
		TriggerCooldowns[Player][CardName] = os.clock()
	end
end

function CardService.CharacterAdded(Character: Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local PlayerData = PlayerDatas:WaitForChild(Player.Name)
	local Cards = PlayerData:WaitForChild("Cards")

	DisconnectConnections(Player)
	CardService.ResetCards(Player, Character)

	AddConnection(Player, Cards.ChildAdded:Connect(function()
		if Player.Character ~= Character then
			return
		end

		CardService.ResetCards(Player, Character)
	end))

	AddConnection(Player, Cards.ChildRemoved:Connect(function()
		if Player.Character ~= Character then
			return
		end

		CardService.ResetCards(Player, Character)
	end))
end

-- \\ Player Tracker // --

Players.PlayerAdded:Connect(function(Player: Player)
	Player.CharacterAdded:Connect(CardService.CharacterAdded)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	DisconnectConnections(Player)
	RunCleanups(Player)

	TriggerCooldowns[Player] = nil
	ActiveCleanups[Player] = nil
end)

for _, Player in ipairs(Players:GetPlayers()) do
	Player.CharacterAdded:Connect(CardService.CharacterAdded)

	if Player.Character then
		CardService.CharacterAdded(Player.Character)
	end
end

return CardService
