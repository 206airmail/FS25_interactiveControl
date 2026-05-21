------------------------------------------------------------------------------------------------------------------------
-- InteractiveAxisPoint
------------------------------------------------------------------------------------------------------------------------
-- Purpose: Interactive action class for axis drag control — mouse hold + drag drives a moving tool.
--
---@author John Deere 6930 @VertexDezign
------------------------------------------------------------------------------------------------------------------------

---@class InteractiveAxisPoint: InteractiveClickPoint
InteractiveAxisPoint = {}

local interactiveAxisPoint_mt = Class(InteractiveAxisPoint, InteractiveClickPoint)

-- Vehicle-only; shares the same visual click-point infrastructure
InteractiveAxisPoint.INPUT_TYPES = { InteractiveController.INPUT_TYPES.VEHICLE }
InteractiveAxisPoint.KEY_NAME = "axisPoint"

---Register AXIS_POINT interactive action
InteractiveAction.registerInteractiveAction("AXIS_POINT", InteractiveAxisPoint)

---Register XMLPaths to XMLSchema
---@param schema XMLSchema Instance of XMLSchema to register path to
---@param basePath string Base path for path registrations
---@param controllerPath string Controller path for path registrations
function InteractiveAxisPoint.registerXMLPaths(schema, basePath, controllerPath)
    InteractiveAxisPoint:superClass().registerXMLPaths(schema, basePath, controllerPath)

    schema:register(XMLValueType.FLOAT, basePath .. "#sensitivity", "Speed multiplier relative to in-vehicle mouse control (1.0 = identical feel, 2.0 = twice as fast)", 1.0)
    schema:register(XMLValueType.STRING, basePath .. "#dragAxis", "Mouse axis used to drive the tool: Y (up/down, default) or X (left/right)", "Y")
end

---Creates new instance of InteractiveAxisPoint
---@param modName string mod name
---@param modDirectory string mod directory
---@param customMt? metatable custom metatable
---@return InteractiveAxisPoint
function InteractiveAxisPoint.new(modName, modDirectory, customMt)
    local self = InteractiveAxisPoint:superClass().new(modName, modDirectory, customMt or interactiveAxisPoint_mt)

    self.sensitivity = 1.0
    self.dragAxis = "Y"
    -- Set the field so InteractiveClickPoint's hover auto-execute check skips this action type.
    self.requireHolding = true

    return self
end

---Loads InteractiveAxisPoint data from xmlFile
---@param xmlFile XMLFile Instance of XMLFile
---@param key string XML key to load from
---@param target any Target vehicle
---@param interactiveController InteractiveController Instance of InteractiveController
---@return boolean loaded
function InteractiveAxisPoint:loadFromXML(xmlFile, key, target, interactiveController)
    if not InteractiveAxisPoint:superClass().loadFromXML(self, xmlFile, key, target, interactiveController) then
        return false
    end

    self.sensitivity = xmlFile:getValue(key .. "#sensitivity", 1.0)

    local dragAxis = xmlFile:getValue(key .. "#dragAxis", "Y"):upper()
    if dragAxis ~= "X" and dragAxis ~= "Y" then
        Logging.xmlWarning(xmlFile, "axisPoint: invalid dragAxis '%s', expected X or Y — defaulting to Y", dragAxis)
        dragAxis = "Y"
    end
    self.dragAxis = dragAxis

    return true
end

---Returns true — axis points always require the button to be held
---@return boolean requireHolding
function InteractiveAxisPoint:requiresHolding()
    return true
end

---Returns true — identifies this action as an axis drag action (not a simple click)
---@return boolean isAxis
function InteractiveAxisPoint:isAxisAction()
    return true
end

---Returns the drag sensitivity for this axis point
---@return number sensitivity
function InteractiveAxisPoint:getAxisSensitivity()
    return self.sensitivity
end

---Returns the mouse axis used to drive this axis point ("X" or "Y")
---@return string dragAxis
function InteractiveAxisPoint:getDragAxis()
    return self.dragAxis
end
