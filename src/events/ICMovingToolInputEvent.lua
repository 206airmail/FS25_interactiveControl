---@class ICMovingToolInputEvent : Event
ICMovingToolInputEvent = {}

local icMovingToolInputEvent_mt = Class(ICMovingToolInputEvent, Event)

InitEventClass(ICMovingToolInputEvent, "ICMovingToolInputEvent")

function ICMovingToolInputEvent.emptyNew()
    local self = Event.new(icMovingToolInputEvent_mt)
    return self
end

---@param object table Vehicle object
---@param toolIndex integer 1-based index into spec_cylindered.movingTools
---@param moveValue number Move value in Cylindered's internal units (same range as tool.move)
function ICMovingToolInputEvent.new(object, toolIndex, moveValue)
    local self = ICMovingToolInputEvent.emptyNew()
    self.object = object
    self.toolIndex = toolIndex
    self.moveValue = moveValue
    return self
end

function ICMovingToolInputEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.toolIndex = streamReadUInt8(streamId)
    -- Decode using the same 12-bit quantization Cylindered uses for input values (range -5..5)
    self.moveValue = (streamReadUIntN(streamId, 12) / 4095 * 2 - 1) * 5
    if math.abs(self.moveValue) < 0.01 then
        self.moveValue = 0
    end
    self:run(connection)
end

function ICMovingToolInputEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUInt8(streamId, self.toolIndex)
    local quantized = math.floor((math.clamp(self.moveValue / 5, -1, 1) + 1) / 2 * 4095)
    streamWriteUIntN(streamId, quantized, 12)
end

function ICMovingToolInputEvent:run(connection)
    -- Client -> server only; the server's Cylindered:onUpdate() handles position sync back.
    if self.object ~= nil and self.object.spec_cylindered ~= nil then
        local tool = self.object.spec_cylindered.movingTools[self.toolIndex]
        if tool ~= nil then
            tool.move = self.moveValue
            tool.lastInputTime = g_time
        end
    end
end
