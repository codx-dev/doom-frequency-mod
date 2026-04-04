# DoomFrequency

A Project Zomboid mod (Build 42.15+) that connects in-game radio communication to the
[DoomFrequency](https://doomfrequency.fm) WebSocket service, letting players broadcast
`say`/`shout` messages across frequencies to an external audience.

## How it works

```
[PZ client]                   [PZ server]                  [relayer]                 [service]
  say / shout  →  broadcast  →  output file  →  tail  →  wss://ws.doomfrequency.fm
                 command           ↑
                              dispatch file  ←  write  ←  incoming messages
                              (lock file guards concurrent access)
```

1. A player speaks (`say`/`shout`) while holding an active two-way radio.
2. The client sends a `broadcast` command to the server with the message text.
3. The server writes a `msg` line to an `output` file, including the frequency,
   a SHA-256 hash of the username, and the in-game timestamp.
4. The **relayer** tails the `output` file and forwards each line to the WebSocket service.
5. The service can send `broadcast` commands back; the relayer appends them to a `dispatch` file.
6. Every ten in-game minutes the server reads `dispatch` and injects matching messages into the
   game's radio system via `DoomFrequencyBroadcaster`.

## Repository layout

```
DoomFrequency/           PZ mod
relayer/                 Python WebSocket bridge
```

## Requirements

- [just](https://github.com/casey/just)
- **Mod**: Lua 5.4+, [luarocks](https://luarocks.org)
- **Relayer**: Python 3.12+, [uv](https://github.com/astral-sh/uv)

## Setup

`.env` variables:

| Variable                | Description                         |
|-------------------------|-------------------------------------|
| `DOOMFREQUENCY_API_KEY` | API key used to obtain a JWT token. |
Free — register at [doomfrequency.fm](https://doomfrequency.fm/).

## Development

### Mod (Lua)

```sh
just doom::install   # install busted into DoomFrequency/lua_modules/
just doom::test      # run Lua unit tests
```

### Relayer (Python)

```sh
just relayer::sync   # uv sync
just relayer::test   # pytest
just relayer::lint   # ruff check
just relayer::fmt    # ruff format
```

## Installing the mod

Subscribe on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3697471948),
or copy/symlink `DoomFrequency/Contents/` into your Project Zomboid mods directory, then enable
**DoomFrequency** from the in-game mod manager.
