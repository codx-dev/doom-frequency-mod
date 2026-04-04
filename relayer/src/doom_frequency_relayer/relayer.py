"""Main relayer: watches a directory and logs new lines from known files."""

import asyncio
import logging
from pathlib import Path

from .auth import fetch_jwt, get_api_key
from .reader import OUTPUT, tail_file
from .sender import DISPATCH, TokenFactory, send_lines

logger = logging.getLogger(__name__)

WS_URL = "wss://ws.doomfrequency.fm"


async def run(
    directory: Path, *, url: str = WS_URL, skip_jwt: bool = False, world_id: int = 0
) -> None:
    """Start the relayer, tailing *directory*/output and forwarding lines to DoomFrequency."""
    directory = Path(directory)
    if not directory.is_dir():
        raise NotADirectoryError(directory)

    token_factory: TokenFactory | None = None
    if not skip_jwt:
        api_key = get_api_key()

        cached_token: list[str] = []

        async def get_token(*, force_refresh: bool = False) -> str:
            if not cached_token or force_refresh:
                cached_token[:] = [await fetch_jwt(api_key)]
            return cached_token[0]

        token_factory = get_token

    output_file = directory / OUTPUT
    dispatch_file = directory / DISPATCH
    queue: asyncio.Queue[str] = asyncio.Queue()

    async with asyncio.TaskGroup() as tg:
        tg.create_task(tail_file(output_file, queue))
        tg.create_task(
            send_lines(
                url,
                queue,
                token_factory=token_factory,
                dispatch_path=dispatch_file,
                world_id=world_id,
            )
        )
