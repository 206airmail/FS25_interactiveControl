------------------------------------------------------------------------------------------------------------------------
-- InteractiveFunctions_externalMods
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Storage for shared functionalities for external mods
--
---@author John Deere 6930 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---Extension of "src/misc/InteractiveFunctions.lua" for external mods
---@tablelib InteractiveFunctions for external mods

---Returns modClass in modEnvironment if existing, nil otherwise.
---If no modClassName is passed, the modEnvironment will be returned.
---@param modEnvironmentName string name of the mod environment (modName)
---@param modClassName? string|nil name of the mod class
---@return Class|nil modClass
---@return nil|boolean isEnvironment
local function getExternalModClass(modEnvironmentName, modClassName)
    if not g_modIsLoaded[modEnvironmentName] then
        return nil, nil
    end

    local modEnvironment = _G[modEnvironmentName]
    if modEnvironment == nil then
        return nil, nil
    end

    if modClassName == nil then
        return modEnvironment, true
    end

    return modEnvironment[modClassName], false
end

----------------------------------------------- FS25_VariableTirePressure ----------------------------------------------

---Returns true if given axle type is in road, false otherwise
---@param target Vehicle Instance of vehicle
---@param axle string Axle type
---@return boolean isRoadMode
local function isAxleInRoadMode(target, axle)
    local spec = target.spec_variableTirePressure
    if spec == nil or axle == nil then
        return false
    end

    if spec._vtpAxleState == nil then
        return spec.isRoadMode
    end

    local axleState = spec._vtpAxleState[axle]
    return axleState.isRoadMode == nil or axleState.isRoadMode
end

---VTP_TIRE_PRESSURE_TOGGLE_REAR
InteractiveFunctions.addFunction("VTP_TIRE_PRESSURE_TOGGLE_REAR", {
    posFunc = function(target, data, noEventSend)
        local VariableTirePressure = getExternalModClass("FS25_VariableTirePressure", "VariableTirePressure")

        if noEventSend or VariableTirePressure == nil then
            return
        end

        if target.vtpToggleTractorAxleMode ~= nil then
            target:vtpToggleTractorAxleMode("rear")
        end
    end,
    updateFunc = function(target, data)
        local VariableTirePressure = getExternalModClass("FS25_VariableTirePressure", "VariableTirePressure")

        if VariableTirePressure ~= nil then
            return isAxleInRoadMode(target, "rear")
        end
        return nil
    end
})
---VTP_TIRE_PRESSURE_TOGGLE_FRONT
InteractiveFunctions.addFunction("VTP_TIRE_PRESSURE_TOGGLE_FRONT", {
    posFunc = function(target, data, noEventSend)
        local VariableTirePressure = getExternalModClass("FS25_VariableTirePressure", "VariableTirePressure")

        if noEventSend or VariableTirePressure == nil then
            return
        end

        if target.vtpToggleTractorAxleMode ~= nil then
            target:vtpToggleTractorAxleMode("front")
        end
    end,
    updateFunc = function(target, data)
        local VariableTirePressure = getExternalModClass("FS25_VariableTirePressure", "VariableTirePressure")

        if VariableTirePressure ~= nil then
            return isAxleInRoadMode(target, "front")
        end
        return nil
    end
})
---VTP_TIRE_PRESSURE_TOGGLE_ALL
InteractiveFunctions.addFunction("VTP_TIRE_PRESSURE_TOGGLE_ALL", {
    posFunc = function(target, data, noEventSend)
        local VariableTirePressure = getExternalModClass("FS25_VariableTirePressure", "VariableTirePressure")

        if noEventSend or VariableTirePressure == nil then
            return
        end

        if target.vtpToggleTractorAxleMode ~= nil then
            local frontAxleInRoadMode = isAxleInRoadMode(target, "front")
            local rearAxleInRoadMode = isAxleInRoadMode(target, "rear")

            if frontAxleInRoadMode == rearAxleInRoadMode then
                target:vtpToggleTractorAxleMode("front")
                target:vtpToggleTractorAxleMode("rear")
            elseif frontAxleInRoadMode then
                target:vtpToggleTractorAxleMode("front")
            elseif rearAxleInRoadMode then
                target:vtpToggleTractorAxleMode("rear")
            end
        end
    end,
    updateFunc = function(target, data)
        local VariableTirePressure = getExternalModClass("FS25_VariableTirePressure", "VariableTirePressure")

        if VariableTirePressure ~= nil then
            return isAxleInRoadMode(target, "front") and isAxleInRoadMode(target, "rear")
        end
        return nil
    end
})
