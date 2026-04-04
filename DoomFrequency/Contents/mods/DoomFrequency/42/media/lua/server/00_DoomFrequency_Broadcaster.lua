---@class DoomFrequencyBroadcaster
DoomFrequencyBroadcaster          = DoomFrequencyBroadcaster or {}
DoomFrequencyBroadcaster.script   = "DoomFrequencyScript"
DoomFrequencyBroadcaster.bc       = "DoomFrequencyBroadcast"
DoomFrequencyBroadcaster.channels = {}

--- Creates a new script with broadcast.
--- @return RadioScript Broadcastable script.
function DoomFrequencyBroadcaster.newScript()
  local sc = RadioScript.new(DoomFrequencyBroadcaster.script, 0, 0)
  local bc = RadioBroadCast.new(DoomFrequencyBroadcaster.bc, 0, 9999)

  sc:AddBroadcast(bc, true)

  return sc
end

--- Returns a channel for the given frequency.
---
--- Will try to create an amateur channel if not found.
---
--- @param frequency number The channel's frequency.
--- @return RadioChannel|nil Nil if not amateur.
function DoomFrequencyBroadcaster.getAmateurChannel(frequency)
  local mgr = RadioScriptManager.getInstance()
  local channel = nil

  local guid = DoomFrequencyBroadcaster.channels[frequency]
  if guid then
    channel = mgr:getRadioChannel(guid)

    if channel and channel:GetFrequency() ~= frequency then
      channel = nil
      DoomFrequencyBroadcaster.channels[frequency] = nil
    end
  end

  if not channel then
    local channels = mgr:getChannelsList()
    for i = 0, channels:size() - 1 do
      local chan = channels:get(i)
      local freq = chan:GetFrequency()

      if freq == frequency then
        channel = chan
        break
      end
    end
  end

  if not channel then
    local name = "Ad-Hoc " .. frequency
    local script = DoomFrequencyBroadcaster.newScript()

    channel = DynamicRadioChannel.new(name, frequency,
      ChannelCategory.Amateur)

    channel:AddRadioScript(script)
    mgr:AddChannel(channel, true)
  end

  if channel:GetCategory() ~= ChannelCategory.Amateur then
    DoomFrequencyBroadcaster.channels[frequency] = nil
    return
  end

  DoomFrequencyBroadcaster.channels[frequency] = channel:getGUID()

  local script = channel:getRadioScript(DoomFrequencyBroadcaster.script)
  local broadcast = nil

  if script then
    broadcast = script:getBroadcastWithID(DoomFrequencyBroadcaster.bc)
  end

  if not script or not broadcast then
    local newScript = DoomFrequencyBroadcaster.newScript()

    channel:AddRadioScript(newScript)
    channel:update()
  end

  return channel
end

---Broadcasts a message to the frequency
---@param frequency number|nil
---@param msg string
---@param color DoomFrequencyColor|nil
---@return boolean
function DoomFrequencyBroadcaster.broadcast(frequency, msg, color)
  --TODO implement signal range

  local frequencyNumber = tonumber(frequency)
  if not frequencyNumber then return false end
  if not DoomFrequencyUtils.isNotEmpty(msg) then return false end

  local channel = DoomFrequencyBroadcaster.getAmateurChannel(frequencyNumber)
  if not channel then return false end

  DoomFrequencyUtils.log("broadcast(" .. tostring(frequencyNumber) .. "): " .. msg)

  local lineColor = color or DoomFrequencyColor:new()
  local script = channel:getRadioScript(DoomFrequencyBroadcaster.script)
  local broadcast = script:getBroadcastWithID(DoomFrequencyBroadcaster.bc)
  local line = RadioLine.new(msg, lineColor.red, lineColor.green, lineColor.blue)

  --TODO overlapping messages will be overriden.
  --Instead, should get last broadcasted line for the script, and append
  broadcast:getLines():clear()
  broadcast:AddRadioLine(line)
  broadcast:resetLineCounter(true)

  script:Reset()

  channel:setActiveScript(DoomFrequencyBroadcaster.script, 0)
  channel:LoadAiringBroadcast(DoomFrequencyBroadcaster.bc, 0)
  channel:update()

  return true
end
