---@class DoomFrequencyRelayer
DoomFrequencyRelayer = DoomFrequencyRelayer or {}

---@param file string
---@param append boolean
---@return LuaManager.GlobalObject.LuaFileWriter|nil
local function write(file, append)
  local writer = getModFileWriter("DoomFrequency", file, true, append)
  if not writer then
    DoomFrequencyUtils.logError("failed to write to file `" .. file .. "`")
  end
  return writer
end


---@param file string
---@return BufferedReader|nil
local function read(file)
  local reader = getModFileReader("DoomFrequency", file, true)
  if not reader then
    DoomFrequencyUtils.logError("failed to read file `" .. file .. "`")
  end
  return reader
end

---@return boolean
local function lockDispatch()
  local writer = write("lock", false)
  if not writer then return false end

  writer:write("1")
  writer:close()

  return true
end

---@return boolean
local function unlockDispatch()
  local writer = write("lock", false)
  if not writer then return false end

  writer:write("0")
  writer:close()

  return true
end

---Cleans the control files for startup
---@return boolean
function DoomFrequencyRelayer.cleanFiles()
  local isOk = unlockDispatch()

  local writerDispatch = write("dispatch", false)
  if not writerDispatch then
    isOk = false
  else
    writerDispatch:close()
  end

  local writerOutput = write("output", false)
  if not writerOutput then
    isOk = false
  else
    writerOutput:close()
  end

  return isOk
end

---Lock the dispatch file and execute its contents
---@param broadcaster DoomFrequencyBroadcaster
---@return boolean
function DoomFrequencyRelayer.lockAndExecuteDispatch(broadcaster)
  if not lockDispatch() then return false end

  local lines = {}
  local readerDispatch = read("dispatch")
  if not readerDispatch then return unlockDispatch() end

  local dispatchLine = readerDispatch:readLine()
  while dispatchLine do
    table.insert(lines, dispatchLine)
    dispatchLine = readerDispatch:readLine()
  end
  readerDispatch:close()

  local dispatchClean = write("dispatch", false)
  if dispatchClean then dispatchClean:close() end

  unlockDispatch()

  for _, line in ipairs(lines) do
    local fields = {}

    for value in (line .. "|"):gmatch("([^|]*)|") do
      table.insert(fields, value)
    end

    if fields[1] and fields[1] == "broadcast" then
      local frequency = tonumber(fields[2])
      local msg       = fields[3]
      local red       = tonumber(fields[4])
      local green     = tonumber(fields[5])
      local blue      = tonumber(fields[6])
      local color     = DoomFrequencyColor:new(red, green, blue)

      broadcaster.broadcast(frequency, msg, color)
    end
  end
end

---Executes a pulse command to notify the relayer of a game tick
---@return boolean
function DoomFrequencyRelayer.pulse()
  local gameTime = getGameTime()
  local currentDay = gameTime:getDay()
  local currentHour = gameTime:getHour()
  local currentMinutes = gameTime:getMinutes()

  local writer = write("output", true)
  if not writer then return false end

  writer:writeln("pulse|" .. tostring(currentDay) .. "|" .. tostring(currentHour) .. "|" .. tostring(currentMinutes))
  writer:close()

  return true
end

---Relays a message from a player to a frequency
---@param broadcaster DoomFrequencyBroadcaster
---@param frequency number
---@param player IsoPlayer
---@param msg string
---@return boolean
function DoomFrequencyRelayer.message(broadcaster, frequency, player, msg)
  local gameTime = getGameTime()
  local currentDay = gameTime:getDay()
  local currentHour = gameTime:getHour()
  local currentMinutes = gameTime:getMinutes()
  local userName = player:getUsername()
  local userNameHash = DoomFrequencyUtils.sha256(userName)

  local line = tostring(frequency) ..
      "|" ..
      tostring(userNameHash) ..
      "|" ..
      tostring(currentDay) .. "|" .. tostring(currentHour) .. "|" .. tostring(currentMinutes) .. "|" .. msg

  DoomFrequencyUtils.log("dispatching message: " .. msg)

  local writer = write("output", true)
  if not writer then return false end

  writer:writeln("msg|" .. line)
  writer:close()

  return broadcaster.broadcast(frequency, msg)
end
