---@class DoomFrequencyUtils
DoomFrequencyUtils = DoomFrequencyUtils or {}

---@class DoomFrequencyColor
---@field red number
---@field green number
---@field blue number
DoomFrequencyColor = {}
DoomFrequencyColor.__index = DoomFrequencyColor

---Creates a new color instance
---@param red number|nil
---@param green number|nil
---@param blue number|nil
---@return DoomFrequencyColor
function DoomFrequencyColor:new(red, green, blue)
  local o = setmetatable({}, self)

  o.red = tonumber(red) or 0.5
  o.green = tonumber(green) or 1.0
  o.blue = tonumber(blue) or 0.5

  return o
end

---@class DoomFrequencyMessage
---@field msg string
---@field color DoomFrequencyColor
DoomFrequencyMessage = {}
DoomFrequencyMessage.__index = DoomFrequencyMessage

---Creates a new message instance
---@param msg string
---@param color DoomFrequencyColor|nil
---@return DoomFrequencyMessage
function DoomFrequencyMessage:new(msg, color)
  local o = setmetatable({}, self)

  o.msg = msg
  o.color = color or DoomFrequencyColor:new()

  return o
end

---Inspects the player inventory for a broadcastable frequency available
---@param player IsoPlayer
---@return number|nil
function DoomFrequencyUtils.playerBroadcastableFrequency(player)
  local inv = player:getInventory()
  local items = inv:getItems()
  local channel = nil

  for i = 0, items:size() - 1 do
    local item = items:get(i)

    if instanceof(item, "Radio") then
      ---@cast item Radio
      local deviceData = item:getDeviceData()

      if deviceData ~= nil then
        local isTwoWay = deviceData:getIsTwoWay()
        local isTurnedOn = deviceData:getIsTurnedOn()
        local isMuted = deviceData:getMicIsMuted()

        if isTwoWay and isTurnedOn and not isMuted then
          channel = deviceData:getChannel()
          break
        end
      end
    end
  end

  return channel
end

---Checks if the string is not empty
---@param str string
---@return boolean
function DoomFrequencyUtils.isNotEmpty(str)
  return str and str:match("^%s*(.-)%s*$") ~= ""
end

local function band(a, b)
  local result = 0
  local bit = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bor(a, b)
  local result = 0
  local bit = 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bxor(a, b)
  local result = 0
  local bit = 1
  while a > 0 or b > 0 do
    if a % 2 ~= b % 2 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end

local function bnot32(a)
  return 0xFFFFFFFF - a
end

local function rshift(a, n)
  return math.floor(a / 2 ^ n)
end

local function lshift(a, n)
  return (a * 2 ^ n) % 0x100000000
end

local function rrotate(x, n)
  return bor(rshift(x, n), lshift(x, 32 - n))
end

local k = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

---Sha256 implementation
---@param msg string
---@return string
function DoomFrequencyUtils.sha256(msg)
  local h0 = 0x6a09e667
  local h1 = 0xbb67ae85
  local h2 = 0x3c6ef372
  local h3 = 0xa54ff53a
  local h4 = 0x510e527f
  local h5 = 0x9b05688c
  local h6 = 0x1f83d9ab
  local h7 = 0x5be0cd19

  local msgLen = #msg
  local bitLen = msgLen * 8

  msg = msg .. "\x80"
  while #msg % 64 ~= 56 do
    msg = msg .. "\x00"
  end
  for i = 7, 0, -1 do
    msg = msg .. string.char(rshift(bitLen, i * 8) % 256)
  end

  local w = {}

  for chunkStart = 1, #msg, 64 do
    for i = 0, 15 do
      local b = chunkStart + i * 4
      w[i] = bor(
        lshift(msg:byte(b), 24),
        bor(
          lshift(msg:byte(b + 1), 16),
          bor(
            lshift(msg:byte(b + 2), 8),
            msg:byte(b + 3)
          )
        )
      )
    end

    for i = 16, 63 do
      local s0 = bxor(rrotate(w[i - 15], 7), bxor(rrotate(w[i - 15], 18), rshift(w[i - 15], 3)))
      local s1 = bxor(rrotate(w[i - 2], 17), bxor(rrotate(w[i - 2], 19), rshift(w[i - 2], 10)))
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 0x100000000
    end

    local a  = h0
    local b  = h1
    local c  = h2
    local d  = h3
    local e  = h4
    local f  = h5
    local g  = h6
    local hh = h7

    for i = 0, 63 do
      local S1    = bxor(rrotate(e, 6), bxor(rrotate(e, 11), rrotate(e, 25)))
      local ch    = bxor(band(e, f), band(bnot32(e), g))
      local temp1 = (hh + S1 + ch + k[i + 1] + w[i]) % 0x100000000
      local S0    = bxor(rrotate(a, 2), bxor(rrotate(a, 13), rrotate(a, 22)))
      local maj   = bxor(band(a, b), bxor(band(a, c), band(b, c)))
      local temp2 = (S0 + maj) % 0x100000000

      hh          = g
      g           = f
      f           = e
      e           = (d + temp1) % 0x100000000
      d           = c
      c           = b
      b           = a
      a           = (temp1 + temp2) % 0x100000000
    end

    h0 = (h0 + a) % 0x100000000
    h1 = (h1 + b) % 0x100000000
    h2 = (h2 + c) % 0x100000000
    h3 = (h3 + d) % 0x100000000
    h4 = (h4 + e) % 0x100000000
    h5 = (h5 + f) % 0x100000000
    h6 = (h6 + g) % 0x100000000
    h7 = (h7 + hh) % 0x100000000
  end

  return string.format("%08x%08x%08x%08x%08x%08x%08x%08x",
    h0, h1, h2, h3, h4, h5, h6, h7)
end

---Logs a message to the console
---@param str string
function DoomFrequencyUtils.log(str)
  print("[DoomFrequency] [log] " .. str)
end

---Logs an error to the console
---@param str string
function DoomFrequencyUtils.logError(str)
  print("[DoomFrequency] [error] " .. str)
end
