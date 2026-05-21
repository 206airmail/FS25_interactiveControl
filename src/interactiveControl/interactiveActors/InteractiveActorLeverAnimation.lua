------------------------------------------------------------------------------------------------------------------------
-- InteractiveActorLeverAnimation
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Drives an animation to visually reflect the current axis drag direction.
--          While dragging positive (e.g. mouse up / right), the animation moves toward 1.0.
--          While dragging negative, it moves toward 0.0.
--          When the drag stops or the hold is released, the animation returns to neutralTime (default 0.5).
--
---@author John Deere 6930 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@class InteractiveActorLeverAnimation: InteractiveActor
InteractiveActorLeverAnimation = {}

local interactiveActorLeverAnimation_mt = Class(InteractiveActorLeverAnimation, InteractiveActor)

InteractiveActorLeverAnimation.INPUT_TYPES = { InteractiveController.INPUT_TYPES.VEHICLE }
InteractiveActorLeverAnimation.KEY_NAME = "leverAnimation"

---Register LEVER_ANIMATION interactive actor
InteractiveActor.registerInteractiveActor("LEVER_ANIMATION", InteractiveActorLeverAnimation)

---Register XMLPaths to XMLSchema
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
---@param controllerPath string Controller path for path registrations
function InteractiveActorLeverAnimation.registerXMLPaths(schema, basePath, controllerPath)
    InteractiveActorLeverAnimation:superClass().registerXMLPaths(schema, basePath, controllerPath)

    schema:register(XMLValueType.STRING, basePath .. "#name", "Animation name to drive as the lever visual")
    schema:register(XMLValueType.FLOAT,  basePath .. "#neutralTime", "Animation time (0-1) to hold when not dragging — typically 0.5 for a centred lever", 0.5)
    schema:register(XMLValueType.FLOAT,  basePath .. "#speed", "How fast the lever animation snaps to its target, in full animation lengths per second (e.g. 3.0 = reaches target in ~0.33s)", 3.0)
end

---Creates new instance of InteractiveActorLeverAnimation
---@param modName string mod name
---@param modDirectory string mod directory
---@param customMt? metatable custom metatable
---@return InteractiveActorLeverAnimation
function InteractiveActorLeverAnimation.new(modName, modDirectory, customMt)
    local self = InteractiveActorLeverAnimation:superClass().new(modName, modDirectory, customMt or interactiveActorLeverAnimation_mt)

    self.name = nil
    self.neutralTime = 0.5
    self.speed = 3.0
    self.driveSpeed = 0

    return self
end

---Loads InteractiveActorLeverAnimation data from xmlFile
---@param xmlFile XMLFile Instance of XMLFile
---@param key string XML key to load from
---@param target any Target vehicle
---@param interactiveController InteractiveController Instance of InteractiveController
---@return boolean loaded
function InteractiveActorLeverAnimation:loadFromXML(xmlFile, key, target, interactiveController)
    if not InteractiveActorLeverAnimation:superClass().loadFromXML(self, xmlFile, key, target, interactiveController) then
        return false
    end

    self.name = xmlFile:getValue(key .. "#name")
    if self.name == nil then
        Logging.xmlWarning(xmlFile, "leverAnimation requires '#name' (animation name), ignoring actor!")
        return false
    end

    self.neutralTime = xmlFile:getValue(key .. "#neutralTime", 0.5)
    self.speed = xmlFile:getValue(key .. "#speed", 3.0)

    return true
end

---Receives the current axis drive speed from the mouse hook each frame.
---Called by InteractiveController:setAxisDriveSpeed which fans out to all actors with setDriveSpeed.
---@param speed number Current mouse axis value scaled by IC sensitivity (positive or negative)
function InteractiveActorLeverAnimation:setDriveSpeed(speed)
    self.driveSpeed = speed
end

---Called each frame. Interpolates the lever animation toward 1.0, 0.0, or neutralTime
---depending on the current drag direction.
function InteractiveActorLeverAnimation:update(isIndoor, isOutdoor, hasInput)
    if self.name == nil then return end

    local targetTime
    if self.interactiveController.isHoldActive and self.driveSpeed ~= 0 then
        targetTime = self.driveSpeed > 0 and 1.0 or 0.0
    else
        targetTime = self.neutralTime
    end

    local currentTime = self.target:getAnimationTime(self.name)
    local diff = targetTime - currentTime

    if math.abs(diff) > 0.001 then
        local step = self.speed * g_currentDt * 0.001
        local newTime = currentTime + math.clamp(diff, -step, step)
        self.target:setAnimationTime(self.name, newTime, true)
    end

    self.driveSpeed = 0
end

---Lever animation has no persistent state to save
---@return boolean isSavingAllowed
function InteractiveActorLeverAnimation:isSavingAllowed()
    return false
end
