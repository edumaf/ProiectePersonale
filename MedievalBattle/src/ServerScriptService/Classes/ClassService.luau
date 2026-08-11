--!strict
--[[
	ClassService

	Owns "what is this player carrying and how much health do they have".

	Everything it knows comes from ClassConfig - there is no per-class code
	anywhere in this file, and there must never be. Adding a fifth class should
	be a table entry plus a line in ClassConfig.Order, nothing more.

	Class changes always take effect on the *next* spawn. Swapping loadout
	mid-fight would be a free heal and a free escape from a recovery.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Modules.ClassConfig)
local CombatConfig = require(ReplicatedStorage.Modules.CombatConfig)
local MapConfig = require(ReplicatedStorage.Modules.MapConfig)
local Remotes = require(ReplicatedStorage.RemoteEvents.Remotes)
local WeaponConfig = require(ReplicatedStorage.Modules.WeaponConfig)

local CombatService = require(script.Parent.Parent.Combat.CombatService)
local RateLimiter = require(script.Parent.Parent.Combat.RateLimiter)
local TeamService = require(script.Parent.Parent.Rounds.TeamService)
local WeaponFactory = require(script.Parent.WeaponFactory)

local ClassService = {}

-- Class the player will spawn as next. Survives death, so you pick once.
local selected: { [Player]: string } = {}

local selectLimiter =
	RateLimiter.new(CombatConfig.RateLimits.ClassSelect.tokens, CombatConfig.RateLimits.ClassSelect.perSecond)

local respawnRequest: ((player: Player) -> ())? = nil

--[[
	SpawnService injects its respawn function here rather than being required,
	which keeps ClassService free of a dependency on spawning (and the two out
	of a require cycle).
]]
function ClassService.setRespawnHandler(handler: (player: Player) -> ())
	respawnRequest = handler
end

function ClassService.getSelected(player: Player): string
	return selected[player] or ClassConfig.Default
end

--[[
	A team-coloured surcoat and a class-coloured plume. Player avatars are all
	different, so team identity cannot rely on the avatar itself - at 50v50 the
	single most important readability question is "can I hit this person".
]]
local function applyLivery(character: Model, teamId: number?)
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local teamColor = if teamId then MapConfig.TeamColors[teamId] else Color3.fromRGB(200, 200, 200)

	if torso then
		local surcoat = Instance.new("Part")
		surcoat.Name = "Surcoat"
		surcoat.Size = torso.Size + Vector3.new(0.16, -0.4, 0.16)
		surcoat.Color = teamColor
		surcoat.Material = Enum.Material.Fabric
		surcoat.Anchored = false
		surcoat.CanCollide = false
		surcoat.CanQuery = false -- never block a swing trace
		surcoat.CanTouch = false
		surcoat.Massless = true
		surcoat.CFrame = torso.CFrame
		surcoat.Parent = character

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = surcoat
		weld.Parent = surcoat
	end

	if head then
		local plume = Instance.new("Part")
		plume.Name = "Plume"
		plume.Size = Vector3.new(0.3, 1.1, 0.3)
		plume.Color = teamColor
		plume.Material = Enum.Material.Fabric
		plume.Anchored = false
		plume.CanCollide = false
		plume.CanQuery = false
		plume.CanTouch = false
		plume.Massless = true
		plume.CFrame = head.CFrame * CFrame.new(0, 0.9, 0)
		plume.Parent = character

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = plume
		weld.Parent = plume
	end
end

--[[
	Applies a class to a freshly spawned character. Called by SpawnService
	*before* CombatService.bindCharacter, so the combat state is created with
	the right weapon and stamina pool already in place.
]]
function ClassService.applyLoadout(player: Player, character: Model)
	local classId = ClassService.getSelected(player)
	local def = ClassConfig.get(classId)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = def.MaxHealth
		humanoid.Health = def.MaxHealth
		humanoid.WalkSpeed = def.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = 6.5
		-- Health bars over heads are the cheapest possible target-selection UI
		-- in a 100-player brawl.
		humanoid.HealthDisplayDistance = 60
		humanoid.NameDisplayDistance = 60
	end

	WeaponFactory.clear(character)

	local weaponId = def.Weapons[1]
	local weapon = WeaponFactory.build(weaponId)
	WeaponFactory.attach(character, weapon)

	if def.HasShield then
		local shield = WeaponFactory.buildShield()
		WeaponFactory.attachShield(character, shield)
	end

	applyLivery(character, TeamService.getTeamId(player))

	character:SetAttribute("ClassId", classId)
	CombatService.setLoadout(player, classId, weaponId, def.StaminaMax)
end

--[[
	Swaps to the next weapon in the class's list (Archer: bow <-> dagger).
	Classes with a single weapon simply do nothing.
]]
function ClassService.cycleWeapon(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local def = ClassConfig.get(ClassService.getSelected(player))
	if #def.Weapons < 2 then
		return
	end

	local state = CombatService.getState(player)
	if not state or not state.alive then
		return
	end

	local currentIndex = table.find(def.Weapons, state.weaponId) or 1
	local nextId = def.Weapons[(currentIndex % #def.Weapons) + 1]
	if not WeaponConfig.find(nextId) then
		return
	end

	WeaponFactory.clear(character)
	local model = WeaponFactory.build(nextId)
	WeaponFactory.attach(character, model)
	if def.HasShield then
		WeaponFactory.attachShield(character, WeaponFactory.buildShield())
	end
	applyLivery(character, TeamService.getTeamId(player))

	CombatService.setWeapon(player, nextId)
end

local function onSelectClass(player: Player, classId: unknown)
	if not selectLimiter:consume(player) then
		return
	end
	if not ClassConfig.isValid(classId) then
		return
	end

	selected[player] = classId :: string
	Remotes.get("LoadoutUpdate"):FireClient(player, classId, ClassConfig.get(classId :: string).Weapons[1])

	-- Dead or not yet spawned: honour the pick immediately so the class menu
	-- doubles as the respawn button. Alive: it applies next time you die.
	local state = CombatService.getState(player)
	local isAlive = state ~= nil and state.alive
	if not isAlive and respawnRequest then
		respawnRequest(player)
	else
		Remotes.get("Notify"):FireClient(player, `{ClassConfig.get(classId :: string).Name} selected - respawn to use it`, 3)
	end
end

local function onSwapWeapon(player: Player)
	if not selectLimiter:consume(player) then
		return
	end
	ClassService.cycleWeapon(player)
end

function ClassService.init()
	Remotes.get("SelectClass").OnServerEvent:Connect(onSelectClass)
	Remotes.get("SwapWeapon").OnServerEvent:Connect(onSwapWeapon)

	Players.PlayerRemoving:Connect(function(player)
		selected[player] = nil
		selectLimiter:forget(player)
	end)
end

return ClassService
