---@param chat ChatMessage
---@param tabId number|nil
local function onAddMessage(chat, tabId)
  local _ = tabId
  local player = getPlayer()

  if player:getUsername() ~= chat:getAuthor() then
    return
  end

  local chatBase = chat:getChat()
  -- type doesn't seem to be properly declared
  local chatType = tostring(chatBase:getType())

  if chatType == "say" or chatType == "shout" then
    local channel = DoomFrequencyUtils.playerBroadcastableFrequency(player)
    if not channel then return end

    sendClientCommand(player, "DoomFrequency", "broadcast", { msg = chat:getText() })
  end
end

Events.OnAddMessage.Add(onAddMessage)
