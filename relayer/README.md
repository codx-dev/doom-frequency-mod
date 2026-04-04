# doom-frequency-relayer

Bridges a local directory to the [DoomFrequency](https://doomfrequency.fm) WebSocket service.

- Tails an `output` file and forwards every new line to `wss://ws.doomfrequency.fm`
- Receives messages from the WebSocket and appends them to a `dispatch` file
- Authenticates via API key → JWT (24h expiry, refreshed on every reconnect)
- Reconnects automatically on connection loss

## How it works

```
[external app]                  [doom-frequency-relayer]            [DoomFrequency]
  writes line  →  output file  →  tail_file  →  send_lines  →→→  wss://ws.doomfrequency.fm
                dispatch file  ←  send_lines  ←←←←←←←←←←←←←←←  incoming messages
```

Write to `output` with a trailing newline. The relayer picks up new lines as they appear and
sends each one as a WebSocket message. Incoming messages are appended to `dispatch`, respecting
a `lock` file (see below).

### Lock file

Before writing to `dispatch`, the relayer checks for a `lock` file in the same directory. If
`lock` exists and its contents are `1`, the write is deferred by 500 ms and retried until the
lock is clear. This allows external processes to safely read `dispatch` without racing the
relayer.

## Requirements

- Python 3.12+
- [uv](https://github.com/astral-sh/uv)
- [just](https://github.com/casey/just)

## Setup

```sh
just install
cp .env.example .env
# edit .env and set DOOMFREQUENCY_API_KEY
```

## Running

```sh
just run              # watches ../common/output, connects to wss://ws.doomfrequency.fm
just run /path/to/dir # watches a custom directory
```

### Local testing

Start a local echo server in one terminal:

```sh
just mock
```

Then run the relayer without JWT in another:

```sh
just run-local
```

## CLI reference

```
doom-frequency-relayer [directory] [--url URL] [--skip-jwt] [--log-level LEVEL]

  directory     Directory containing the output/dispatch/lock files.
                Defaults to <package_dir>/../common.

  --url         WebSocket URL to connect to.
                Defaults to wss://ws.doomfrequency.fm.

  --skip-jwt    Skip API key lookup and JWT authentication.
                Intended for local testing.

  --log-level   Logging verbosity: DEBUG, INFO, WARNING, ERROR. Default: INFO.
```

## Environment

| Variable                | Description                          |
|-------------------------|--------------------------------------|
| `DOOMFREQUENCY_API_KEY` | API key used to obtain a JWT token.  |

Loaded automatically from `.env` if present.

## Development

```sh
just test     # run tests
just lint     # ruff check
just fmt      # ruff format
just check    # lint + format check (CI)
just build    # build wheel and sdist
```
