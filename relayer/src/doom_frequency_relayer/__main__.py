"""Entry point: python -m doom_frequency_relayer."""

import asyncio
import logging
import sys
from argparse import ArgumentParser
from pathlib import Path

import httpx
import websockets.exceptions

from .auth import MissingCredentialsError
from .relayer import WS_URL, run


def main() -> None:
    parser = ArgumentParser(
        description="Relay files from a directory to the DoomFrequency WebSocket."
    )
    parser.add_argument(
        "directory",
        type=Path,
        help="Directory to watch ('dispatch', 'lock', and 'output' files will be created"
        " if missing)",
    )
    parser.add_argument(
        "--url",
        default=WS_URL,
        help="WebSocket URL to connect to; defaults to %(default)s",
    )
    parser.add_argument(
        "--world-id",
        type=int,
        default=0,
        help="World ID sent as X-World-ID header; defaults to %(default)s",
    )
    parser.add_argument(
        "--skip-jwt",
        action="store_true",
        help="Skip JWT authentication (useful for local testing)",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=args.log_level,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        stream=sys.stderr,
    )

    try:
        for name in ("dispatch", "lock", "output"):
            (args.directory / name).touch()
    except FileNotFoundError as exc:
        print(f"Error: required file not found: {exc.filename}", file=sys.stderr)
        sys.exit(1)
    except PermissionError as exc:
        print(f"Error: permission denied: {exc.filename}", file=sys.stderr)
        sys.exit(1)

    try:
        asyncio.run(
            run(args.directory, url=args.url, skip_jwt=args.skip_jwt, world_id=args.world_id)
        )
    except NotADirectoryError:
        print(f"Error: '{args.directory}' is not a directory.", file=sys.stderr)
        sys.exit(1)
    except MissingCredentialsError as exc:
        print(f"Error: {exc}. Set DOOMFREQUENCY_API_KEY in your environment.", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        sys.exit(0)
    except BaseExceptionGroup as eg:
        for exc in eg.exceptions:
            if isinstance(exc, websockets.exceptions.InvalidStatus):
                print(
                    f"Error: WebSocket handshake failed: {exc.response.status_code}"
                    f" {exc.response.reason_phrase}",
                    file=sys.stderr,
                )
            elif isinstance(exc, httpx.HTTPStatusError):
                print(
                    f"Error: Auth request failed: {exc.response.status_code}"
                    f" {exc.response.reason_phrase}",
                    file=sys.stderr,
                )
            elif isinstance(exc, httpx.RequestError):
                print(f"Error: Auth request error: {exc}", file=sys.stderr)
            elif isinstance(exc, (FileNotFoundError, PermissionError)):
                print(f"Error: {type(exc).__name__}: {exc.filename}", file=sys.stderr)
            elif isinstance(exc, KeyError):
                print(f"Error: Unexpected auth response, missing key: {exc}", file=sys.stderr)
            else:
                print(f"Error: {type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
