local M = {}
M.type = "auxiliary"

local htmlTexture = require("htmlTexture")
local turboGlowTemp
local turboStartGlow
local tempEndGlow
local startmiddleGlowAmount
local middleGlowAmount
local endGlowAmount
local firstTime = true
local maxGlow

local function init(jbeamData)
	local firstTime = false
	turboStartGlow = jbeamData.turboStartGlow or (jbeamData.turboGlowTemp * 0.7)
	turboGlowTemp = jbeamData.turboGlowTemp
	tempEndGlow = (jbeamData.tempEndGlow) or (jbeamData.turboGlowTemp * 1.5)
	maxGlow = jbeamData.maxGlow or 1
	startmiddleGlowAmount = 0
	--print("startmiddleGlowAmount= "..startmiddleGlowAmount)
	middleGlowAmount = turboGlowTemp - turboStartGlow
	--print("middleGlowAmount= "..middleGlowAmount)
	endGlowAmount = tempEndGlow -turboStartGlow
	--print("endGlowAmount= "..endGlowAmount)
	--print("in init *****************************************************^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    htmlTexture.create("@turboGlowValue", "local://local/vehicles/pigeon/turboGlow.html", 40, 40, 50, "automatic")
    htmlTexture.call("@turboGlowValue", "init", 0)
end

local function reset()
	htmlTexture.call("@turboGlowValue", "init", 0)
end

local function updateGFX(dt)
	local turboTemp = controller.mainController.fireEngineTemperature --[[exhaust temp]] + (electrics.values.watertemp or 0) + electrics.values.oiltemp --+ (electrics.values.turboBoost or 0)
	--print("turboTemp = "..turboTemp)
	if turboTemp > turboStartGlow then
		local t = linearScale(turboTemp, turboStartGlow, tempEndGlow, 0,maxGlow)
		--print("t= "..t)
		local currentHeatOverStartGlow = startmiddleGlowAmount + turboTemp
		local currentmiddleGlowAmount = quadraticBezier(startmiddleGlowAmount, middleGlowAmount, endGlowAmount, t)
		--print("currentmiddleGlowAmount= "..currentmiddleGlowAmount)

		--[[ local currentmiddleGlowAmount = (startmiddleGlowAmount + turboTemp) * 0.01
		print("currentmiddleGlowAmount= "..currentmiddleGlowAmount)

		if turboTemp > turboGlowTemp then
			local tempDiff = (turboGlowTemp - turboStartGlow) * 0.01
			print("tempDiff= "..tempDiff)
			currentmiddleGlowAmount = tempDiff + middleGlowAmount + turboTemp
			local bloomThreshold = 22
			local speedRampMult = 1
			if currentmiddleGlowAmount <= bloomThreshold then
				currentmiddleGlowAmount = currentmiddleGlowAmount * speedRampMult
				--print("multiplying by 3= ".. currentmiddleGlowAmount)
			else
				currentmiddleGlowAmount = currentmiddleGlowAmount + (bloomThreshold*(speedRampMult-1))
				--print("default= ".. currentmiddleGlowAmount)
			end
		end ]]
		htmlTexture.call("@turboGlowValue", "update", currentmiddleGlowAmount)
	end
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX

return M
