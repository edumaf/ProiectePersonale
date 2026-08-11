--!strict
--[[
	Client

	The one client entry point, mirroring Main.server.luau. Every other file in
	StarterPlayerScripts is a ModuleScript with an init(), so the load order is
	explicit and a broken controller cannot silently take the rest down with it.
]]

local CameraController = require(script.Parent.Combat.CameraController)
local EffectController = require(script.Parent.Combat.EffectController)
local HUD = require(script.Parent.UI.HUD)
local InputController = require(script.Parent.Combat.InputController)
local SwingAnimator = require(script.Parent.Combat.SwingAnimator)

local controllers: { { name: string, init: () -> () } } = {
	{ name = "HUD", init = HUD.init },
	{ name = "SwingAnimator", init = SwingAnimator.init },
	{ name = "CameraController", init = CameraController.init },
	{ name = "InputController", init = InputController.init },
	{ name = "EffectController", init = EffectController.init },
}

for _, controller in controllers do
	local ok, err = pcall(controller.init)
	if not ok then
		warn(`[MedievalBattle] {controller.name} failed to start: {err}`)
	end
end
