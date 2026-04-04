local function onEveryTenMinutes()
  DoomFrequencyRelayer.pulse()
  DoomFrequencyRelayer.lockAndExecuteDispatch(DoomFrequencyBroadcaster)
end

local function onClientCommand(module, command, player, args)
  if module ~= "DoomFrequency" then return end
  if command == "broadcast" then
    local frequency = DoomFrequencyUtils.playerBroadcastableFrequency(player)
    local hasMsg = DoomFrequencyUtils.isNotEmpty(args.msg)

    if frequency and hasMsg then
      DoomFrequencyRelayer.message(DoomFrequencyBroadcaster, frequency, player, args.msg)
    end
  end
end

local function onServerStarted()
  DoomFrequencyRelayer.cleanFiles()
  DoomFrequencyUtils.log("initialized")
end

--apparently the client also calls the server routines
if not isClient() then
  Events.EveryTenMinutes.Add(onEveryTenMinutes)
  Events.OnClientCommand.Add(onClientCommand)
  Events.OnServerStarted.Add(onServerStarted)
end
