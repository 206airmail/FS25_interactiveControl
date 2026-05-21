------------------------------------------------------------------------------------------------------------------------
-- InteractiveActorMovingTool
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Interactive actor that drives a Cylindered moving tool via axis input (mouse drag).
--
---@author John Deere 6930 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@class InteractiveActorMovingTool: InteractiveActor
InteractiveActorMovingTool = {}

local interactiveActorMovingTool_mt = Class(InteractiveActorMovingTool, InteractiveActor)

-- Vehicle-only; moving tools only exist on vehicles with the Cylindered specialization
InteractiveActorMovingTool.INPUT_TYPES = { InteractiveController.INPUT_TYPES.VEHICLE }
InteractiveActorMovingTool.KEY_NAME = "axisMovingTool"

---Register AXIS_MOVING_TOOL interactive actor
InteractiveActor.registerInteractiveActor("AXIS_MOVING_TOOL", InteractiveActorMovingTool)

---Register XMLPaths to XMLSchema
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
---@param controllerPath string Controller path for path registrations
function InteractiveActorMovingTool.registerXMLPaths(schema, basePath, controllerPath)
    InteractiveActorMovingTool:superClass().registerXMLPaths(schema, basePath, controllerPath)

    schema:register(XMLValueType.NODE_INDEX, basePath .. "#node", "Moving tool node (alternative to #movingToolIndex)")
    schema:register(XMLValueType.INT, basePath .. "#movingToolIndex", "1-based index of the moving tool in <cylindered><movingTools> (alternative to #node)")
end

---Creates new instance of InteractiveActorMovingTool
---@param modName string mod name
---@param modDirectory string mod directory
---@param customMt? metatable custom metatable
---@return InteractiveActorMovingTool
function InteractiveActorMovingTool.new(modName, modDirectory, customMt)
    local self = InteractiveActorMovingTool:superClass().new(modName, modDirectory, customMt or interactiveActorMovingTool_mt)

    self.movingTool = nil
    self.driveSpeed = 0

    return self
end

---Loads InteractiveActorMovingTool data from xmlFile
---@param xmlFile XMLFile Instance of XMLFile
---@param key string XML key to load from
---@param target any Target vehicle
---@param interactiveController InteractiveController Instance of InteractiveController
---@return boolean loaded
function InteractiveActorMovingTool:loadFromXML(xmlFile, key, target, interactiveController)
    if not InteractiveActorMovingTool:superClass().loadFromXML(self, xmlFile, key, target, interactiveController) then
        return false
    end

    local spec = target.spec_cylindered
    if spec == nil then
        Logging.xmlWarning(xmlFile, "axisMovingTool requires a vehicle with the Cylindered specialization, ignoring actor!")
        return false
    end

    -- Support two reference styles: by moving tool index (preferred) or by node name.
    local movingToolIndex = xmlFile:getValue(key .. "#movingToolIndex")
    if movingToolIndex ~= nil then
        self.movingTool = spec.movingTools[movingToolIndex]
        if self.movingTool == nil then
            Logging.xmlWarning(xmlFile, "axisMovingTool: no moving tool at movingToolIndex=%d (vehicle has %d tools), ignoring actor!", movingToolIndex, #spec.movingTools)
            return false
        end
    else
        local node = xmlFile:getValue(key .. "#node", nil, target.components, target.i3dMappings)
        if node == nil then
            Logging.xmlWarning(xmlFile, "axisMovingTool requires '#movingToolIndex' or '#node', ignoring actor!")
            return false
        end
        self.movingTool = target:getMovingToolByNode(node)
        if self.movingTool == nil then
            Logging.xmlWarning(xmlFile, "axisMovingTool: no movingTool found at the specified node, ignoring actor!")
            return false
        end
    end

    return true
end

---Sets the drive speed applied each frame while the axis hold is active.
---This is the raw mouse axis value scaled by IC sensitivity, passed through the same formula
---Cylindered uses for in-vehicle mouse input.
---@param speed number Raw mouse axis value scaled by IC sensitivity
function InteractiveActorMovingTool:setDriveSpeed(speed)
    self.driveSpeed = speed
end

---Applies an input value to the moving tool using the same formula Cylindered uses for in-vehicle
---mouse dragging: invertAxis → armSensitivity → (16.666/dt) → mouseSpeedFactor → tool.move.
---@param inputValue number The value to apply (0 to stop the tool)
function InteractiveActorMovingTool:applyInputToTool(inputValue)
    local tool = self.movingTool
    local move = tool.invertAxis and -inputValue or inputValue
    local armSens = g_gameSettings:getValue(GameSettings.SETTING.VEHICLE_ARM_SENSITIVITY)
    move = move * armSens
    local mouseSpeedFactor = tool.mouseSpeedFactor or 1
    move = move * 16.666 / g_currentDt * mouseSpeedFactor

    tool.lastInputTime = g_time

    if move ~= tool.move then
        tool.move = move
    end
    if tool.move ~= tool.moveToSend then
        tool.moveToSend = tool.move
        self.target:raiseDirtyFlags(self.target.spec_cylindered.cylinderedInputDirtyFlag)
    end
end

---Called each frame — drives the moving tool using the same formula as Cylindered's in-vehicle
---mouse input path. driveSpeed is set by the mouse-hook each frame and is 0 when the mouse is
---still, causing the tool to stop (matching in-vehicle behaviour).
---Only runs on the controlling client (hasInput=true); the server receives tool.move via the
---cylinderedInputDirtyFlag network sync and must not zero it independently.
function InteractiveActorMovingTool:update(isIndoor, isOutdoor, hasInput)
    if self.movingTool == nil or not hasInput then return end

    if not self.interactiveController.isHoldActive then
        if self.movingTool.move ~= 0 then
            self:applyInputToTool(0)
        end
        self.driveSpeed = 0
        return
    end

    self:applyInputToTool(self.driveSpeed)
    self.driveSpeed = 0
end

---Returns false (with a warning popup) if requiresEngine is set on the active action and the engine is not running.
---Called before an axis hold starts.
---@return boolean canStart
function InteractiveActorMovingTool:canStartHold()
    local activeAction = self.interactiveController.activeAction
    if activeAction ~= nil and activeAction.requiresEngine then
        local rootVehicle = self.target.rootVehicle
        if rootVehicle ~= nil and rootVehicle.getIsMotorStarted ~= nil and not rootVehicle:getIsMotorStarted() then
            g_currentMission:showBlinkingWarning(g_i18n:getText("warning_motorNotStarted"), 2000)
            return false
        end
    end
    return true
end

---Moving tools do not persist state through IC's stateValue system
---@return boolean isSavingAllowed
function InteractiveActorMovingTool:isSavingAllowed()
    return false
end

---Disable analog mode for moving tool actors (state value has no meaning here)
---@return boolean isAnalogAllowed
function InteractiveActorMovingTool:isAnalogAllowed()
    return false
end
