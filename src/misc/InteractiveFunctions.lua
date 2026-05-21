------------------------------------------------------------------------------------------------------------------------
-- InteractiveFunctions
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Storage for shared functionalities
--
---@author John Deere 6930 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@tablelib InteractiveFunctions
InteractiveFunctions = {}

InteractiveFunctions.FUNCTION_ID = {
    UNKNOWN = 0
}

local lastId = InteractiveFunctions.FUNCTION_ID.UNKNOWN
local function getNextId()
    lastId = lastId + 1
    return lastId
end

---@type table<string, table> Table of function data by name
InteractiveFunctions.FUNCTIONS = {}

---Adds a new function which can be used as InteractiveFunction
---@param functionIdStr string unique function name
---@param functionArgs table<function> functions to use [posFunc, negFunc?, updateFunc?, schemaFunc?, loadFunc?, isBlockedFunc?]
function InteractiveFunctions.addFunction(functionIdStr, functionArgs)
    if functionIdStr == nil or functionIdStr == "" then
        Logging.warning("InteractiveFunction was not added! Invalid functionID!")
        return false
    end

    functionIdStr = functionIdStr:upper()

    if functionArgs.posFunc == nil then
        Logging.warning("InteractiveFunction with ID: %s was not added! No function defined!", functionIdStr)
        return false
    end
    if InteractiveFunctions.FUNCTION_ID[functionIdStr] ~= nil then
        Logging.warning("InteractiveFunction with ID: %s was not added! FunctionID already exists!", functionIdStr)
        return false
    end

    InteractiveFunctions.FUNCTION_ID[functionIdStr] = getNextId()

    local entry = table.clone(functionArgs)

    entry.name = functionIdStr
    entry.functionId = InteractiveFunctions.FUNCTION_ID[functionIdStr]
    entry.negFunc = Utils.getNoNil(entry.negFunc, functionArgs.posFunc)

    InteractiveFunctions.FUNCTIONS[entry.functionId] = entry

    return true
end

---Returns known function data for given function name
---@param functionName string function name to get data
---@return table|nil functionData
function InteractiveFunctions.getFunctionData(functionName)
    local identifier = InteractiveFunctions.FUNCTION_ID[functionName]
    if identifier == nil then
        return nil
    end

    return InteractiveFunctions.FUNCTIONS[identifier]
end

---Shared function to register attacherJoints schematics
---@param schema XMLSchema schema to register attacherJoint
---@param path string path to register attacherJoint
function InteractiveFunctions.attacherJointsSchema(schema, path)
    schema:register(XMLValueType.VECTOR_N, path .. ".attacherJoint#indices", "Attacher joint indices to be controlled", true)
end

---Shared function to load attacherJoints
---@param xmlFile XMLFile Instance of XMLFile
---@param key string path key to load attacherJoint
---@param data table table to store loaded attacherJoint
---@param errorMsg string error message name
---@return boolean loaded
function InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, errorMsg)
    XMLUtil.checkDeprecatedXMLElements(xmlFile, key .. ".attacherJoint#indicies", key .. ".attacherJoint#indices") -- FS22 to FS25
    XMLUtil.checkDeprecatedXMLElements(xmlFile, key .. ".attacherJoint#index", key .. ".attacherJoint#indices")    -- FS22 to FS25

    data.attacherJointIndices = xmlFile:getValue(key .. ".attacherJoint#indices", nil, true)

    if data.attacherJointIndices == nil or table.getn(data.attacherJointIndices) <= 0 then
        Logging.xmlWarning(xmlFile, "Failed to load attacherJoint indices, ignoring control\nSet value '%s.attacherJoint#indices' to use function: %s", key, key, errorMsg)
        return false
    end

    data.currentAttacherIndex = nil
    data.currentAttachedObject = nil
    return true
end

---Shared function to get attached object to vehicle
---@param vehicle Vehicle instance of vehicle to get attached object
---@param attacherJointIndex number index of attacher joint
---@return Vehicle|nil attachedObject
function InteractiveFunctions.resolveToAttachedObject(vehicle, attacherJointIndex)
    if vehicle == nil or attacherJointIndex == nil or vehicle.getImplementByJointDescIndex == nil then
        return nil
    end

    local implement = vehicle:getImplementByJointDescIndex(attacherJointIndex)
    if implement == nil then
        return nil
    end

    if implement.object.getIsSelected == nil then
        Logging.warning("%s: Unable to resolve attacherJointIndex '%s' to valid attached vehicle!", vehicle:getFullName(), attacherJointIndex)
        return nil
    end

    return implement.object
end

---Shared function to get attached object and currently used attacher joint index
---@param data table function data
---@param vehicle Vehicle instance of vehicle to get attached object
---@param validate? function function to validate object
---@return number|nil attacherJointIndex currently used attacherJoint index
---@return Vehicle|nil attachedObject currently used attached vehicle object
function InteractiveFunctions.getAttacherJointObjectToUse(data, vehicle, validate)
    if data.attacherJointIndices == nil or table.getn(data.attacherJointIndices) <= 0 then
        data.currentAttacherIndex = nil
        data.currentAttachedObject = nil

        return nil, nil
    end

    local validAttacherJoints = {}
    for _, attacherJointIndex in ipairs(data.attacherJointIndices) do
        local attachedObject = InteractiveFunctions.resolveToAttachedObject(vehicle, attacherJointIndex)

        if attachedObject ~= nil then
            if validate ~= nil then
                -- collect all valid joint pairs
                if validate(attachedObject) then
                    local validEntry = {
                        attacherJointIndex = attacherJointIndex,
                        attachedObject = attachedObject
                    }

                    if not table.hasElement(validAttacherJoints, validEntry) then
                        table.addElement(validAttacherJoints, validEntry)
                    end
                end
            else
                -- return first joint index with attached vehicle, if no validate function is given
                data.currentAttacherIndex = attacherJointIndex
                data.currentAttachedObject = attachedObject

                return attacherJointIndex, attachedObject
            end
        end
    end

    if #validAttacherJoints > 1 then
        -- return first selected joint pair
        for index, object in pairs(validAttacherJoints) do
            if object.getIsSelected ~= nil and object:getIsSelected() then
                data.currentAttacherIndex = index
                data.currentAttachedObject = object

                return index, object
            end
        end
    end

    if validAttacherJoints[1] ~= nil then
        -- return first valid joint if only one is given or nothing selected
        data.currentAttacherIndex = validAttacherJoints[1].attacherJointIndex
        data.currentAttachedObject = validAttacherJoints[1].attachedObject

        return data.currentAttacherIndex, data.currentAttachedObject
    end

    data.currentAttacherIndex = nil
    data.currentAttachedObject = nil
    return nil, nil
end

---FUNCTION_MOTOR_START_STOPP
InteractiveFunctions.addFunction("MOTOR_START_STOPP", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if not g_currentMission.missionInfo.automaticMotorStartEnabled and target.getCanMotorRun ~= nil and target.startMotor ~= nil then
            if target:getCanMotorRun() then
                target:startMotor(noEventSend)
            end
        end
    end,
    negFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if not g_currentMission.missionInfo.automaticMotorStartEnabled and target.stopMotor ~= nil then
            target:stopMotor(noEventSend)
        end
    end,
    updateFunc = function(target, data)
        if not g_currentMission.missionInfo.automaticMotorStartEnabled and target.getIsMotorStarted ~= nil then
            return target:getIsMotorStarted()
        end
        return nil
    end,
    isBlockedFunc = function(target, data)
        return not g_currentMission.missionInfo.automaticMotorStartEnabled
    end
})

---FUNCTION_LIGHTS_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setNextLightsState ~= nil then
            if target:getCanToggleLight() then
                target:setNextLightsState(1)
            end
        end
    end
})

---FUNCTION_LIGHTS_WORKBACK_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_WORKBACK_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setLightsTypesMask ~= nil then
            if target:getCanToggleLight() then
                local lightsTypesMask = bitXOR(target.spec_lights.lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_WORK_BACK)
                target:setLightsTypesMask(lightsTypesMask, true, noEventSend)
            end
        end
    end
})

---FUNCTION_LIGHTS_WORKFRONT_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_WORKFRONT_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setLightsTypesMask ~= nil then
            if target:getCanToggleLight() then
                local lightsTypesMask = bitXOR(target.spec_lights.lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_WORK_FRONT)
                target:setLightsTypesMask(lightsTypesMask, true, noEventSend)
            end
        end
    end
})

---FUNCTION_LIGHTS_HIGHBEAM_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_HIGHBEAM_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setLightsTypesMask ~= nil then
            if target:getCanToggleLight() then
                local lightsTypesMask = bitXOR(target.spec_lights.lightsTypesMask, 2 ^ Lights.LIGHT_TYPE_HIGHBEAM)
                target:setLightsTypesMask(lightsTypesMask, true, noEventSend)
            end
        end
    end
})

---FUNCTION_LIGHTS_TURNLIGHT_HAZARD_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_TURNLIGHT_HAZARD_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setTurnLightState ~= nil then
            if target:getCanToggleLight() then
                local state = Lights.TURNLIGHT_OFF
                if target.spec_lights.turnLightState ~= Lights.TURNLIGHT_HAZARD then
                    state = Lights.TURNLIGHT_HAZARD
                end

                target:setTurnLightState(state, true, noEventSend)
            end
        end
    end,
    updateFunc = function(target, data)
        if target.getTurnLightState ~= nil then
            return target:getTurnLightState() == Lights.TURNLIGHT_HAZARD
        end
        return nil
    end
})

---FUNCTION_LIGHTS_TURNLIGHT_LEFT_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_TURNLIGHT_LEFT_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setTurnLightState ~= nil then
            if target:getCanToggleLight() then
                local state = Lights.TURNLIGHT_OFF
                if target.spec_lights.turnLightState ~= Lights.TURNLIGHT_LEFT then
                    state = Lights.TURNLIGHT_LEFT
                end

                target:setTurnLightState(state, true, noEventSend)
            end
        end
    end,
    updateFunc = function(target, data)
        if target.getTurnLightState ~= nil then
            return target:getTurnLightState() == Lights.TURNLIGHT_LEFT
        end
        return nil
    end
})

---FUNCTION_LIGHTS_TURNLIGHT_RIGHT_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_TURNLIGHT_RIGHT_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setTurnLightState ~= nil then
            if target:getCanToggleLight() then
                local state = Lights.TURNLIGHT_OFF
                if target.spec_lights.turnLightState ~= Lights.TURNLIGHT_RIGHT then
                    state = Lights.TURNLIGHT_RIGHT
                end

                target:setTurnLightState(state, true, noEventSend)
            end
        end
    end,
    updateFunc = function(target, data)
        if target.getTurnLightState ~= nil then
            return target:getTurnLightState() == Lights.TURNLIGHT_RIGHT
        end
        return nil
    end
})

---FUNCTION_LIGHTS_BEACON_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_BEACON_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setBeaconLightsVisibility ~= nil then
            target:setBeaconLightsVisibility(not target.spec_lights.beaconLightsActive, true, noEventSend)
        end
    end,
    updateFunc = function(target, data)
        if target.getBeaconLightsVisibility ~= nil then
            return target:getBeaconLightsVisibility()
        end
        return nil
    end
})

---FUNCTION_LIGHTS_PIPE_TOGGLE
InteractiveFunctions.addFunction("LIGHTS_PIPE_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleLight ~= nil and target.setLightsTypesMask ~= nil then
            if target:getCanToggleLight() then
                -- lighttype for pipe lights is "4"
                local lightsTypesMask = bitXOR(target.spec_lights.lightsTypesMask, 2 ^ 4)
                target:setLightsTypesMask(lightsTypesMask, true, noEventSend)
            end
        end
    end
})

---FUNCTION_AUTOMATIC_STEERING_TOGGLE
InteractiveFunctions.addFunction("AUTOMATIC_STEERING_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        if target:getIsAutomaticSteeringAllowed() then
            AIAutomaticSteering.actionEventSteering(target)
        end
    end,
    updateFunc = function(target, data)
        local state = target:getAIAutomaticSteeringState()
        if state ~= nil then
            return state == AIAutomaticSteering.STATE.ACTIVE
        end
        return nil
    end,
    isBlockedFunc = function(target, data)
        local state = target:getAIAutomaticSteeringState()
        if state ~= nil then
            return state == AIAutomaticSteering.STATE.ACTIVE or state == AIAutomaticSteering.STATE.AVAILABLE
        end
        return false
    end
})

---FUNCTION_AUTOMATIC_STEERING_LINES_TOGGLE
InteractiveFunctions.addFunction("AUTOMATIC_STEERING_LINES_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        if target:getIsAutomaticSteeringAllowed() then
            AIAutomaticSteering.actionEventSteeringLines(target)
        end
    end,
    updateFunc = function(target, data)
        return g_gameSettings:getValue(GameSettings.SETTING.STEERING_ASSIST_LINES)
    end,
    isBlockedFunc = function(target, data)
        local state = target:getAIAutomaticSteeringState()
        if state ~= nil then
            return state ~= nil and state == AIAutomaticSteering.STATE.ACTIVE or state == AIAutomaticSteering.STATE.AVAILABLE
        end
        return false
    end
})

---FUNCTION_CRUISE_CONTROL_TOGGLE
InteractiveFunctions.addFunction("CRUISE_CONTROL_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if target.isClient then
            if target.spec_drivable ~= nil then
                target.spec_drivable.lastInputValues.cruiseControlState = 1
            end
        end
    end
})

---FUNCTION_DRIVE_DIRECTION_TOGGLE
InteractiveFunctions.addFunction("DRIVE_DIRECTION_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        MotorGearShiftEvent.sendToServer(target, MotorGearShiftEvent.TYPE_DIRECTION_CHANGE)
    end,
    isBlockedFunc = function(target, data)
        if target.spec_motorized ~= nil then
            return target:getDirectionChangeMode() == VehicleMotor.DIRECTION_CHANGE_MODE_MANUAL
                or target:getGearShiftMode() ~= VehicleMotor.SHIFT_MODE_AUTOMATIC
        end
        return false
    end
})

---FUNCTION_COVER_TOGGLE
InteractiveFunctions.addFunction("COVER_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.playCoverAnimation ~= nil and Cover.actionEventToggleCover ~= nil then
            Cover.actionEventToggleCover(target)
        end
    end,
    updateFunc = function(target, data)
        if target.spec_cover ~= nil then
            return target.spec_cover.state ~= 0
        end
        return nil
    end
})

---Returns true if target is equal to controlled player vehicle, false otherwise
---@param target Vehicle
---@return boolean isEqual
local function controlledIsEqualTarget(target)
    if g_localPlayer == nil then
        return false
    end

    local controlledVehicle = g_localPlayer:getCurrentVehicle()
    if controlledVehicle == nil then
        return false
    end

    return controlledVehicle == target
end

---FUNCTION_RADIO_TOGGLE
InteractiveFunctions.addFunction("RADIO_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if g_soundPlayer ~= nil and controlledIsEqualTarget(target) then
            PlayerInputComponent.onInputToggleRadio()
        end
    end,
    updateFunc = function(target, data)
        if g_currentMission.getIsRadioPlaying ~= nil then
            return g_currentMission:getIsRadioPlaying()
        end
        return nil
    end,
    isBlockedFunc = function(target, data)
        if g_soundPlayer ~= nil then
            local isVehicleOnly = g_gameSettings:getValue(GameSettings.SETTING.RADIO_VEHICLE_ONLY)

            return not isVehicleOnly or isVehicleOnly and target ~= nil and target.supportsRadio
        end
        return nil
    end
})

---FUNCTION_RADIO_CHANNEL_NEXT
InteractiveFunctions.addFunction("RADIO_CHANNEL_NEXT", {
    posFunc = function(target, data, noEventSend)
        if g_soundPlayer ~= nil and controlledIsEqualTarget(target) then
            g_soundPlayer:nextChannel()
        end
    end,
    isBlockedFunc = function(target, data)
        if g_soundPlayer ~= nil then
            local isVehicleOnly = g_gameSettings:getValue(GameSettings.SETTING.RADIO_VEHICLE_ONLY)

            return not isVehicleOnly or isVehicleOnly and target ~= nil and target.supportsRadio
        end
        return nil
    end
})

---FUNCTION_RADIO_CHANNEL_PREVIOUS
InteractiveFunctions.addFunction("RADIO_CHANNEL_PREVIOUS", {
    posFunc = function(target, data, noEventSend)
        if g_soundPlayer ~= nil and controlledIsEqualTarget(target) then
            g_soundPlayer:previousChannel()
        end
    end,
    isBlockedFunc = function(target, data)
        if g_soundPlayer ~= nil then
            local isVehicleOnly = g_gameSettings:getValue(GameSettings.SETTING.RADIO_VEHICLE_ONLY)

            return not isVehicleOnly or isVehicleOnly and target ~= nil and target.supportsRadio
        end
        return nil
    end
})

---FUNCTION_RADIO_ITEM_NEXT
InteractiveFunctions.addFunction("RADIO_ITEM_NEXT", {
    posFunc = function(target, data, noEventSend)
        if g_soundPlayer ~= nil and controlledIsEqualTarget(target) then
            g_soundPlayer:nextItem()
        end
    end,
    isBlockedFunc = function(target, data)
        if g_soundPlayer ~= nil then
            local isVehicleOnly = g_gameSettings:getValue(GameSettings.SETTING.RADIO_VEHICLE_ONLY)

            return not isVehicleOnly or isVehicleOnly and target ~= nil and target.supportsRadio
        end
        return nil
    end
})

---FUNCTION_RADIO_ITEM_PREVIOUS
InteractiveFunctions.addFunction("RADIO_ITEM_PREVIOUS", {
    posFunc = function(target, data, noEventSend)
        if g_soundPlayer ~= nil and controlledIsEqualTarget(target) then
            g_soundPlayer:previousItem()
        end
    end,
    isBlockedFunc = function(target, data)
        if g_soundPlayer ~= nil then
            local isVehicleOnly = g_gameSettings:getValue(GameSettings.SETTING.RADIO_VEHICLE_ONLY)

            return not isVehicleOnly or isVehicleOnly and target ~= nil and target.supportsRadio
        end
        return nil
    end
})

---FUNCTION_REVERSEDRIVING_TOGGLE
InteractiveFunctions.addFunction("REVERSEDRIVING_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        if target.spec_reverseDriving ~= nil and target.spec_reverseDriving.hasReverseDriving and target:getIsReverseDrivingAllowed() ~= nil then
            ReverseDriving.actionEventToggleReverseDriving(target)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.spec_reverseDriving.hasReverseDriving == true and target.getIsReverseDrivingAllowed ~= nil then
            return target:getIsReverseDrivingAllowed()
        end
        return nil
    end
})

---Shared function to lower objects, if required also on all attached vehicles
---@param index integer|nil jointDesc index of attacher joint
---@param target any vehicle to lower implements at
---@param state boolean is lowered state
---@param attachedObject? Vehicle|nil root vehicle for chain lowering
---@param noEventSend? boolean send no event to connection
function InteractiveFunctions.setLoweredStateRec(index, target, state, attachedObject, noEventSend)
    if attachedObject ~= nil then
        if attachedObject.getAttachedImplements ~= nil then
            local attachedImplements = attachedObject:getAttachedImplements()

            if attachedImplements ~= nil then
                for _, attachedImplement in ipairs(attachedImplements) do
                    local object = attachedImplement.object
                    local jointDescIndex = attachedImplement.jointDescIndex

                    if object ~= nil or jointDescIndex ~= nil then
                        InteractiveFunctions.setLoweredStateRec(jointDescIndex, attachedObject, state, object, noEventSend)
                    end
                end
            end
        end

        -- change folding animations
        if Foldable.actionEventFoldMiddle ~= nil and attachedObject.getIsFoldMiddleAllowed ~= nil and attachedObject:getIsFoldMiddleAllowed() then
            local dir = state and -1 or 1
            if attachedObject:getToggledFoldMiddleDirection() == dir then
                if noEventSend then
                    return
                end

                Foldable.actionEventFoldMiddle(attachedObject)
            end

            return
        end

        -- change pickup state
        if attachedObject.spec_pickup ~= nil then
            attachedObject:setPickupState(state, noEventSend)

            return
        end
    end

    -- change attacherJoints state
    if index ~= nil and target ~= nil then
        if target.handleLowerImplementByAttacherJointIndex ~= nil then
            target:handleLowerImplementByAttacherJointIndex(index, state)
        end
    end
end

---FUNCTION_ATTACHERJOINTS_LIFT_LOWER
InteractiveFunctions.addFunction("ATTACHERJOINTS_LIFT_LOWER", {
    posFunc = function(target, data, noEventSend)
        InteractiveFunctions.setLoweredStateRec(data.currentAttacherIndex, target, true, data.currentAttachedObject, noEventSend)
    end,
    negFunc = function(target, data, noEventSend)
        InteractiveFunctions.setLoweredStateRec(data.currentAttacherIndex, target, false, data.currentAttachedObject, noEventSend)
    end,
    updateFunc = function(target, data)
        if data.currentAttachedObject ~= nil then
            if data.currentAttachedObject.getIsLowered ~= nil then
                return data.currentAttachedObject:getIsLowered()
            end
        end

        return nil
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_LIFT_LOWER")
    end,
    isBlockedFunc = function(target, data)
        ---Returns true if any vehicle in implement chain can be lowered, false otherwise
        ---@param object Vehicle
        ---@return boolean isLoweringAllowed
        local function isLoweringChainedAllowed(object)
            if object.spec_attacherJointControl ~= nil then
                return false
            end

            if object.spec_pickup ~= nil then
                return true
            end

            if object.getAllowsLowering ~= nil and object:getAllowsLowering() then
                return true
            end

            local chainImplements = object:getAttachedImplements()
            if chainImplements ~= nil then
                for _, chainImplement in ipairs(chainImplements) do
                    if chainImplement.object ~= nil then
                        return isLoweringChainedAllowed(chainImplement.object)
                    end
                end
            end

            return false
        end

        local attacherJointIndex, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, isLoweringChainedAllowed)

        return attacherJointIndex ~= nil and attachedObject ~= nil
    end
})

---FUNCTION_TURN_ON_OFF
InteractiveFunctions.addFunction("TURN_ON_OFF", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanBeTurnedOn ~= nil then
            if target:getCanToggleTurnedOn() and target:getCanBeTurnedOn() then
                target:setIsTurnedOn(not target:getIsTurnedOn())
            elseif not target:getIsTurnedOn() then
                local warning = target:getTurnedOnNotAllowedWarning()

                if warning ~= nil then
                    g_currentMission:showBlinkingWarning(warning, 2000)
                end
            end
        end
    end,
    updateFunc = function(target, data)
        if target.getIsTurnedOn ~= nil then
            return target:getIsTurnedOn()
        end
        return nil
    end,
    isBlockedFunc = function(target, data)
        return target.getCanBeTurnedOn ~= nil
    end
})

---FUNCTION_ATTACHERJOINTS_TURN_ON_OFF
InteractiveFunctions.addFunction("ATTACHERJOINTS_TURN_ON_OFF", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil and TurnOnVehicle.actionEventTurnOn ~= nil then
            TurnOnVehicle.actionEventTurnOn(attachedObject)
        end
    end,
    updateFunc = function(target, data)
        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil then
            return attachedObject:getIsTurnedOn()
        end

        return nil
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_TURN_ON_OFF")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            return object.getCanBeTurnedOn ~= nil and object.spec_turnOnVehicle ~= nil
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_FOLDING_TOGGLE
InteractiveFunctions.addFunction("FOLDING_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local spec_foldable = target.spec_foldable
        if spec_foldable == nil then
            return
        end

        if spec_foldable.requiresPower and not target:getIsPowered() then
            local warning = g_i18n:getText("warning_motorNotStarted")

            if warning ~= nil then
                g_currentMission:showBlinkingWarning(warning, 2000)
            end

            return
        end

        if target.getIsFoldAllowed ~= nil and Foldable.actionEventFold ~= nil then
            Foldable.actionEventFold(target)
        end
    end,
    updateFunc = function(target, data)
        if target.getToggledFoldDirection ~= nil then
            return target:getToggledFoldDirection() == 1
        end
        return nil
    end
})

---FUNCTION_ATTACHERJOINTS_FOLDING_TOGGLE
InteractiveFunctions.addFunction("ATTACHERJOINTS_FOLDING_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject
        if attachedObject ~= nil and Foldable.actionEventFold ~= nil then
            Foldable.actionEventFold(attachedObject)
        end
    end,
    updateFunc = function(target, data)
        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil then
            return attachedObject:getToggledFoldDirection() == 1
        end
        return nil
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_FOLDING_TOGGLE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            return object.spec_foldable ~= nil and #object.spec_foldable.foldingParts > 0 and not object.spec_foldable.useParentFoldingState
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_PIPE_FOLDING_TOGGLE
InteractiveFunctions.addFunction("PIPE_FOLDING_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        -- Show warning if target is not unfolded
        if target.getIsUnfolded ~= nil and not target:getIsUnfolded() then
            local warning = target:getTurnedOnNotAllowedWarning()

            if warning ~= nil then
                g_currentMission:showBlinkingWarning(warning, 2000)
                return
            end
        end

        if target.getIsPipeStateChangeAllowed ~= nil and Pipe.actionEventTogglePipe ~= nil then
            Pipe.actionEventTogglePipe(target)
        end
    end,
    updateFunc = function(target, data)
        if target.spec_pipe.targetState ~= nil then
            return target.spec_pipe.targetState == 1
        end
    end
})

---FUNCTION_DISCHARGE_TOGGLE
InteractiveFunctions.addFunction("DISCHARGE_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getDischargeState ~= nil then
            local dischargeState = target:getDischargeState()
            local currentDischargeNode = target:getCurrentDischargeNode()

            if dischargeState == Dischargeable.DISCHARGE_STATE_OFF then
                if target:getIsDischargeNodeActive(currentDischargeNode) then
                    if target:getCanDischargeToObject(currentDischargeNode) and target:getCanToggleDischargeToObject() then
                        Dischargeable.actionEventToggleDischarging(target)
                    elseif target:getCanDischargeToGround(currentDischargeNode) and
                        target:getCanToggleDischargeToGround() then
                        Dischargeable.actionEventToggleDischargeToGround(target)
                    end
                end
            else
                Dischargeable.actionEventToggleDischarging(target)
            end
        end
    end,
    updateFunc = function(target, data)
        if target.getDischargeState ~= nil then
            return target:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
        end
        return nil
    end
})

---FUNCTION_ATTACHERJOINTS_DISCHARGE_TOGGLE
InteractiveFunctions.addFunction("ATTACHERJOINTS_DISCHARGE_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil then
            local currentDischargeNode = attachedObject:getCurrentDischargeNode()

            if attachedObject:getIsDischargeNodeActive(currentDischargeNode) then
                if attachedObject:getCanDischargeToObject(currentDischargeNode) and attachedObject:getCanToggleDischargeToObject() then
                    Dischargeable.actionEventToggleDischarging(attachedObject)
                elseif attachedObject:getCanDischargeToGround(currentDischargeNode) and attachedObject:getCanToggleDischargeToGround() then
                    Dischargeable.actionEventToggleDischargeToGround(attachedObject)
                end
            end
        end
    end,
    updateFunc = function(target, data)
        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil then
            return attachedObject:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
        end
        return nil
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_DISCHARGE_TOGGLE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            return object.spec_dischargeable ~= nil and object.getCanToggleDischargeToObject ~= nil and object:getCanToggleDischargeToObject()
                or object.getCanToggleDischargeToGround ~= nil and object:getCanToggleDischargeToGround()
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_CRABSTEERING_TOGGLE
InteractiveFunctions.addFunction("CRABSTEERING_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.getCanToggleCrabSteering ~= nil and CrabSteering.actionEventToggleCrabSteeringModes ~= nil then
            CrabSteering.actionEventToggleCrabSteeringModes(target, nil, nil, 1)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.getCanToggleCrabSteering ~= nil then
            return target:getCanToggleCrabSteering()
        end
        return nil
    end
})

---FUNCTION_VARIABLE_WORK_WIDTH_LEFT_INCREASE
InteractiveFunctions.addFunction("VARIABLE_WORK_WIDTH_LEFT_INCREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.spec_variableWorkWidth and VariableWorkWidth.actionEventWorkWidthLeft ~= nil then
            VariableWorkWidth.actionEventWorkWidthLeft(target, nil, 1)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.spec_variableWorkWidth ~= nil then
            local spec = target.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesLeft > 0
        end
        return false
    end
})

---FUNCTION_VARIABLE_WORK_WIDTH_LEFT_DECREASE
InteractiveFunctions.addFunction("VARIABLE_WORK_WIDTH_LEFT_DECREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.spec_variableWorkWidth and VariableWorkWidth.actionEventWorkWidthLeft ~= nil then
            VariableWorkWidth.actionEventWorkWidthLeft(target, nil, -1)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.spec_variableWorkWidth ~= nil then
            local spec = target.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesLeft > 0
        end
        return false
    end
})

---FUNCTION_ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_INCREASE
InteractiveFunctions.addFunction("ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_INCREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil and VariableWorkWidth.actionEventWorkWidthLeft ~= nil then
            VariableWorkWidth.actionEventWorkWidthLeft(attachedObject, nil, 1)
        end
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_INCREASE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            if object.spec_variableWorkWidth == nil then
                return false
            end

            local spec = object.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesLeft > 0
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_DECREASE
InteractiveFunctions.addFunction("ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_DECREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil and VariableWorkWidth.actionEventWorkWidthLeft ~= nil then
            VariableWorkWidth.actionEventWorkWidthLeft(attachedObject, nil, -1)
        end
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_VARIABLE_WORK_WIDTH_LEFT_DECREASE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            if object.spec_variableWorkWidth == nil then
                return false
            end

            local spec = object.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesLeft > 0
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_VARIABLE_WORK_WIDTH_RIGHT_INCREASE
InteractiveFunctions.addFunction("VARIABLE_WORK_WIDTH_RIGHT_INCREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.spec_variableWorkWidth and VariableWorkWidth.actionEventWorkWidthRight ~= nil then
            VariableWorkWidth.actionEventWorkWidthRight(target, nil, 1)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.spec_variableWorkWidth ~= nil then
            local spec = target.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesRight > 0
        end
        return false
    end
})

---FUNCTION_VARIABLE_WORK_WIDTH_RIGHT_DECREASE
InteractiveFunctions.addFunction("VARIABLE_WORK_WIDTH_RIGHT_DECREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.spec_variableWorkWidth and VariableWorkWidth.actionEventWorkWidthRight ~= nil then
            VariableWorkWidth.actionEventWorkWidthRight(target, nil, -1)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.spec_variableWorkWidth ~= nil then
            local spec = target.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesRight > 0
        end
        return false
    end
})

---FUNCTION_ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_INCREASE
InteractiveFunctions.addFunction("ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_INCREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil and VariableWorkWidth.actionEventWorkWidthRight ~= nil then
            VariableWorkWidth.actionEventWorkWidthRight(attachedObject, nil, 1)
        end
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_INCREASE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            if object.spec_variableWorkWidth == nil then
                return false
            end

            local spec = object.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesRight > 0
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_DECREASE
InteractiveFunctions.addFunction("ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_DECREASE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil and VariableWorkWidth.actionEventWorkWidthRight ~= nil then
            VariableWorkWidth.actionEventWorkWidthRight(attachedObject, nil, -1)
        end
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_VARIABLE_WORK_WIDTH_RIGHT_DECREASE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            if object.spec_variableWorkWidth == nil then
                return false
            end

            local spec = object.spec_variableWorkWidth
            return #spec.sectionNodes > 0 and #spec.sectionNodesRight > 0
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_VARIABLE_WORK_WIDTH_TOGGLE
InteractiveFunctions.addFunction("VARIABLE_WORK_WIDTH_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        if target.spec_variableWorkWidth and VariableWorkWidth.actionEventWorkWidthToggle ~= nil then
            VariableWorkWidth.actionEventWorkWidthToggle(target)
        end
    end,
    isBlockedFunc = function(target, data)
        if target.spec_variableWorkWidth ~= nil then
            return #target.spec_variableWorkWidth.sectionNodes > 0
        end
        return false
    end
})

---FUNCTION_ATTACHERJOINTS_VARIABLE_WORK_WIDTH_TOGGLE
InteractiveFunctions.addFunction("ATTACHERJOINTS_VARIABLE_WORK_WIDTH_TOGGLE", {
    posFunc = function(target, data, noEventSend)
        local attachedObject = data.currentAttachedObject

        if attachedObject ~= nil and VariableWorkWidth.actionEventWorkWidthToggle ~= nil then
            VariableWorkWidth.actionEventWorkWidthToggle(attachedObject)
        end
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_VARIABLE_WORK_WIDTH_TOGGLE")
    end,
    isBlockedFunc = function(target, data)
        local _, attachedObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
            if object.spec_variableWorkWidth == nil then
                return false
            end

            local spec = object.spec_variableWorkWidth
            return #spec.sectionNodes > 0
        end)

        return attachedObject ~= nil
    end
})

---FUNCTION_ATTACHERJOINTS_ATTACH_DETACH
InteractiveFunctions.ATTACH_DETACH_UPDATE_COUNT = 50 -- calls
InteractiveFunctions.addFunction("ATTACHERJOINTS_ATTACH_DETACH", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local info = target.spec_attacherJoints.attachableInfo

        if info.attachable ~= nil then
            if info.attachable:isAttachAllowed(target:getActiveFarm(), info.attacherVehicle) then
                if target.isServer then
                    target:attachImplementFromInfo(info)
                else
                    g_client:getServerConnection():sendEvent(VehicleAttachRequestEvent.new(info))
                end
            end
        end
    end,
    negFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end

        local detachableObject = data.currentAttachedObject

        if detachableObject ~= nil and detachableObject ~= target then
            if detachableObject:isDetachAllowed() then
                detachableObject:startDetachProcess()
            end
        end
    end,
    updateFunc = function(target, data)
        data.currentUpdateIndex = data.currentUpdateIndex + 1

        if data.currentUpdateIndex > InteractiveFunctions.ATTACH_DETACH_UPDATE_COUNT then
            data.currentUpdateIndex = 1

            if target:isOutdoorActive() then
                AttacherJoints.updateVehiclesInAttachRange(target, AttacherJoints.MAX_ATTACH_DISTANCE_SQ, AttacherJoints.MAX_ATTACH_ANGLE, true)
            end
        end

        local detachableObject = data.currentAttachedObject
        if detachableObject ~= nil then
            return true
        end

        local attacherVehicle, attacherVehicleJointDescIndex, attachable, attachableJointDescIndex = target:getAttachableInfo()
        if attachable ~= nil and attacherVehicleJointDescIndex ~= nil then
            if table.hasElement(data.attacherJointIndices, attacherVehicleJointDescIndex) then
                if attachable:isAttachAllowed(target:getActiveFarm(), attacherVehicle) then
                    return false
                end
            end
        end

        return nil
    end,
    schemaFunc = InteractiveFunctions.attacherJointsSchema,
    loadFunc = function(xmlFile, key, data)
        data.currentUpdateIndex = 1

        return InteractiveFunctions.attacherJointsLoad(xmlFile, key, data, "ATTACHERJOINTS_ATTACH_DETACH")
    end,
    isBlockedFunc = function(target, data)
        if target.spec_attacherJoints == nil then
            return false
        end

        local attacherVehicle, attacherVehicleJointDescIndex, attachable, attachableJointDescIndex = target:getAttachableInfo()

        -- no attachable vehicle in range
        if attachable == nil then
            -- is there a detachable vehicle?
            local _, detachableObject = InteractiveFunctions.getAttacherJointObjectToUse(data, target, function(object)
                return object.isDetachAllowed ~= nil and object:isDetachAllowed()
            end)

            return detachableObject ~= nil
        end

        -- attachable vehicle in range
        if attacherVehicleJointDescIndex ~= nil and data.attacherJointIndices ~= nil then
            if table.hasElement(data.attacherJointIndices, attacherVehicleJointDescIndex) then
                return attachable:isAttachAllowed(target:getActiveFarm(), attacherVehicle)
            end
        end

        return false
    end
})

---FUNCTION_BALER_TOGGLE_SIZE
InteractiveFunctions.addFunction("BALER_TOGGLE_SIZE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        local spec_baler = target.spec_baler

        if spec_baler ~= nil then
            Baler.actionEventToggleSize(target)
        end
    end,
    forcedActionText = function(target, data, interactiveActor)
        local spec_baler = target.spec_baler
        local actionText = interactiveActor.interactiveController:getActionText(false)

        if spec_baler ~= nil then
            local baleTypeDef = spec_baler.baleTypes[spec_baler.preSelectedBaleTypeIndex]
            local baleSize = 0

            if baleTypeDef ~= nil then
                if baleTypeDef.isRoundBale == true then
                    baleSize = baleTypeDef.diameter
                else
                    baleSize = baleTypeDef.length
                end
            end
            return string.format(actionText, baleSize * 100)
        end
        return actionText
    end,
    isBlockedFunc = function(target, data)
        local spec_baler = target.spec_baler
        local spec_foldableSteps = target.spec_foldableSteps
        if #spec_baler.baleTypes > 1 then
            if spec_foldableSteps ~= nil then
                return spec_foldableSteps.stateIndex == spec_foldableSteps.maxState
            end
            return true
        end
        return false
    end
})

---FUNCTION_BALER_DROP_BALE
InteractiveFunctions.addFunction("BALER_DROP_BALE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        local spec_baler = target.spec_baler

        if spec_baler ~= nil and Baler.isUnloadingAllowed(target) then
            Baler.actionEventUnloading(target)
        end
    end,
    isBlockedFunc = function(target, data)
        local spec_baler = target.spec_baler
        local spec_foldableSteps = target.spec_foldableSteps

        if spec_baler ~= nil then
            local canUnload = (Baler.isUnloadingAllowed(target) and #spec_baler.bales > 0) or (spec_baler.unloadingState == Baler.UNLOADING_OPEN)

            if spec_foldableSteps ~= nil then
                local isFullyUnfolded = spec_foldableSteps.stateIndex == spec_foldableSteps.maxState
                return isFullyUnfolded and canUnload
            end
            return canUnload
        end
        return true
    end
})

---FUNCTION_BALER_TOGGLE_AUTOMATIC_DROP
InteractiveFunctions.addFunction("BALER_TOGGLE_AUTOMATIC_DROP", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        local spec_baler = target.spec_baler

        if spec_baler ~= nil then
            Baler.setBalerAutomaticDrop(target, not spec_baler.automaticDrop)
        end
    end,
    updateFunc = function(target, data)
        local spec_baler = target.spec_baler
        if spec_baler ~= nil then
            return spec_baler.automaticDrop
        end
        return nil
    end,
    isBlockedFunc = function(target, data)
        local spec_foldableSteps = target.spec_foldableSteps
        if spec_foldableSteps ~= nil then
            return spec_foldableSteps.stateIndex == spec_foldableSteps.maxState
        end
        return true
    end
})

---FUNCTION_BALEWRAPPER_DROP_BALE
InteractiveFunctions.addFunction("BALEWRAPPER_DROP_BALE", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        local spec_baleWrapper = target.spec_baleWrapper

        if spec_baleWrapper ~= nil and BaleWrapper.getIsBaleDropAllowed(target) then
            BaleWrapper.actionEventDrop(target)
        end
    end,
    isBlockedFunc = function(target, data)
        local spec_baleWrapper = target.spec_baleWrapper
        local spec_foldableSteps = target.spec_foldableSteps
        local wrapperFinished = spec_baleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED

        if spec_baleWrapper ~= nil then
            local wrapperCanUnload = wrapperFinished and BaleWrapper.getIsBaleDropAllowed(target)

            if spec_foldableSteps ~= nil then
                local isFullyUnfolded = spec_foldableSteps.stateIndex == spec_foldableSteps.maxState
                return isFullyUnfolded and wrapperCanUnload
            end

            return wrapperCanUnload
        end
        return true
    end
})

---FUNCTION_BALEWRAPPER_TOGGLE_AUTOMATIC_DROP
InteractiveFunctions.addFunction("BALEWRAPPER_TOGGLE_AUTOMATIC_DROP", {
    posFunc = function(target, data, noEventSend)
        if noEventSend then
            return
        end
        local spec_baleWrapper = target.spec_baleWrapper

        if spec_baleWrapper ~= nil then
            BaleWrapper.setBaleWrapperAutomaticDrop(target, not spec_baleWrapper.automaticDrop)
        end
    end,
    updateFunc = function(target, data)
        local spec_baleWrapper = target.spec_baleWrapper
        if spec_baleWrapper ~= nil then
            return spec_baleWrapper.automaticDrop
        end
        return nil
    end,
    isBlockedFunc = function(target, data)
        local spec_foldableSteps = target.spec_foldableSteps
        if spec_foldableSteps ~= nil then
            return spec_foldableSteps.stateIndex == spec_foldableSteps.maxState
        end
        return true
    end
})

---FUNCTION_LIGHT_TOGGLE
---Toggles one or more individual lights (bulb + lens) independently of the main vehicle lights system.
---If the nodes are also referenced in <vehicle.lights>, pressing F to cycle lights will take priority
---and overwrite the IC state on the next light change. For IC-exclusive lights, omit them from <vehicle.lights>.
InteractiveFunctions.addFunction("LIGHT_TOGGLE", {
    schemaFunc = function(schema, path)
        schema:register(XMLValueType.NODE_INDEX, path .. ".realLight(?)#node",           "Real light source node (LIGHT_SOURCE class). Must NOT be in <vehicle.lights> — IC owns it exclusively via setVisibility.")
        schema:register(XMLValueType.NODE_INDEX, path .. ".staticLightMesh(?)#node",     "Emissive mesh using the staticLight shader. Must NOT be in <staticLightCompounds> — IC owns it exclusively via lightIds shader params.")
        schema:register(XMLValueType.FLOAT,      path .. ".staticLightMesh(?)#intensity","Emissive intensity when on (default 10). Match the intensity value you would have used on the <staticLightCompound> node.", 10)
    end,
    loadFunc = function(xmlFile, key, data, actor)
        local target = actor.target

        data.realLightNodes = {}
        xmlFile:iterate(key .. ".realLight", function(_, realLightKey)
            local node = xmlFile:getValue(realLightKey .. "#node", nil, target.components, target.i3dMappings)
            if node ~= nil then
                table.insert(data.realLightNodes, node)
            else
                Logging.xmlWarning(xmlFile, "LIGHT_TOGGLE: invalid realLight #node at '%s'", realLightKey)
            end
        end)

        data.staticLightMeshes = {}
        xmlFile:iterate(key .. ".staticLightMesh", function(_, meshKey)
            local node = xmlFile:getValue(meshKey .. "#node", nil, target.components, target.i3dMappings)
            if node == nil then
                Logging.xmlWarning(xmlFile, "LIGHT_TOGGLE: invalid staticLightMesh #node at '%s'", meshKey)
                return
            end
            if not getHasShaderParameter(node, "lightIds0") then
                Logging.xmlWarning(xmlFile, "LIGHT_TOGGLE: staticLightMesh at '%s' is missing the lightIds0 shader parameter — ensure the node uses the staticLight shader variation", meshKey)
                return
            end
            table.insert(data.staticLightMeshes, {
                node      = node,
                intensity = xmlFile:getValue(meshKey .. "#intensity", 10),
            })
        end)

        if #data.realLightNodes == 0 and #data.staticLightMeshes == 0 then
            Logging.xmlWarning(xmlFile, "LIGHT_TOGGLE has no valid nodes at '%s'", key)
            return false
        end

        -- Apply initial off state so i3d-visible nodes match IC's default stateValue of 0.
        for _, node in ipairs(data.realLightNodes) do
            setVisibility(node, false)
        end
        for _, mesh in ipairs(data.staticLightMeshes) do
            setShaderParameter(mesh.node, "lightIds0", 0, 0, 0, 0, false)
            setShaderParameter(mesh.node, "lightIds1", 0, 0, 0, 0, false)
            setShaderParameter(mesh.node, "lightIds2", 0, 0, 0, 0, false)
            setShaderParameter(mesh.node, "lightIds3", 0, 0, 0, 0, false)
        end

        return true
    end,
    posFunc = function(target, data, noEventSend)
        for _, node in ipairs(data.realLightNodes) do
            setVisibility(node, true)
        end
        for _, mesh in ipairs(data.staticLightMeshes) do
            local i = mesh.intensity
            setShaderParameter(mesh.node, "lightIds0", i, i, i, i, false)
            setShaderParameter(mesh.node, "lightIds1", i, i, i, i, false)
            setShaderParameter(mesh.node, "lightIds2", i, i, i, i, false)
            setShaderParameter(mesh.node, "lightIds3", i, i, i, i, false)
        end
    end,
    negFunc = function(target, data, noEventSend)
        for _, node in ipairs(data.realLightNodes) do
            setVisibility(node, false)
        end
        for _, mesh in ipairs(data.staticLightMeshes) do
            setShaderParameter(mesh.node, "lightIds0", 0, 0, 0, 0, false)
            setShaderParameter(mesh.node, "lightIds1", 0, 0, 0, 0, false)
            setShaderParameter(mesh.node, "lightIds2", 0, 0, 0, 0, false)
            setShaderParameter(mesh.node, "lightIds3", 0, 0, 0, 0, false)
        end
    end,
    isBlockedFunc = function(target, data)
        return #data.realLightNodes > 0 or #data.staticLightMeshes > 0
    end
})

-- Shared helpers for WINCH_IN / WINCH_OUT ---------------------------------------------------------

local function winchSchemaFunc(schema, path)
    schema:register(XMLValueType.VECTOR_N, path .. ".winch#ropeIndices", "Space-separated list of 1-based rope indices to control (e.g. \"1 2\" controls both ropes simultaneously)", true)
end

-- loadFunc receives the actor as 4th arg so we can cache the controller for isHoldActive checks.
local function winchLoadFunc(xmlFile, key, data, actor)
    data.ropeIndices = xmlFile:getValue(key .. ".winch#ropeIndices", nil, true)
    if data.ropeIndices == nil or #data.ropeIndices == 0 then
        Logging.xmlWarning(xmlFile, "WINCH function missing required '.winch#ropeIndices' — set at least one rope index (e.g. ropeIndices=\"1\")")
        return false
    end
    if actor ~= nil then
        data.controller = actor.interactiveController
    end
    return true
end

local function winchIsBlockedFunc(vehicle, data)
    local spec = vehicle.spec_winch
    if spec == nil or spec.ropes == nil then
        return false
    end
    for _, ropeIndex in ipairs(data.ropeIndices) do
        if spec.ropes[ropeIndex] ~= nil then
            return true
        end
    end
    return false
end

local function winchControlAll(vehicle, data, direction)
    if vehicle.setWinchControlInput == nil then
        return
    end
    for _, ropeIndex in ipairs(data.ropeIndices) do
        vehicle:setWinchControlInput(ropeIndex, direction)
    end
end

---FUNCTION_WINCH_IN — pulls the rope(s) in while the click point is held
InteractiveFunctions.addFunction("WINCH_IN", {
    schemaFunc = winchSchemaFunc,
    loadFunc = winchLoadFunc,
    requiresHolding = true,
    posFunc = function(vehicle, data)
        winchControlAll(vehicle, data, 1)
    end,
    negFunc = function(vehicle, data)
        winchControlAll(vehicle, data, 0)
    end,
    updateFunc = function(vehicle, data)
        -- Called every frame; keep the winch moving for as long as the hold is active.
        if data.controller ~= nil and data.controller.isHoldActive then
            winchControlAll(vehicle, data, 1)
        end
        return nil
    end,
    isBlockedFunc = winchIsBlockedFunc,
})

---FUNCTION_WINCH_OUT — releases the rope(s) while the click point is held
InteractiveFunctions.addFunction("WINCH_OUT", {
    schemaFunc = winchSchemaFunc,
    loadFunc = winchLoadFunc,
    requiresHolding = true,
    posFunc = function(vehicle, data)
        winchControlAll(vehicle, data, -1)
    end,
    negFunc = function(vehicle, data)
        winchControlAll(vehicle, data, 0)
    end,
    updateFunc = function(vehicle, data)
        if data.controller ~= nil and data.controller.isHoldActive then
            winchControlAll(vehicle, data, -1)
        end
        return nil
    end,
    isBlockedFunc = winchIsBlockedFunc,
})
