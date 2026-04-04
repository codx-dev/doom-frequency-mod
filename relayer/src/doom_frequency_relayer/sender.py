"""DoomFrequency WebSocket sender/receiver."""

import asyncio
import logging
from pathlib import Path
from typing import Protocol

import websockets
from websockets.exceptions import ConnectionClosed, InvalidStatus

logger = logging.getLogger(__name__)

DISPATCH = "dispatch"


class TokenFactory(Protocol):
    async def __call__(self, *, force_refresh: bool = False) -> str: ...


async def send_lines(
    url: str,
    queue: asyncio.Queue[str],
    *,
    token_factory: TokenFactory | None = None,
    dispatch_path: Path | None = None,
    reconnect_delay: float = 5.0,
    world_id: int = 0,
) -> None:
    """Consume lines from *queue* and forward them over a WebSocket.

    If *token_factory* is provided it is called before each connection attempt
    to obtain a fresh JWT (handles 24-hour expiry on reconnects).
    If *dispatch_path* is provided, incoming WebSocket messages are appended to
    that file as newline-terminated lines.
    Reconnects automatically on connection loss.
    """
    force_refresh = False
    while True:
        try:
            headers = {"X-World-ID": str(world_id)}
            if token_factory is not None:
                token = await token_factory(force_refresh=force_refresh)
                headers["Authorization"] = f"Bearer {token}"
            force_refresh = False

            async with websockets.connect(url, additional_headers=headers) as ws:
                logger.info("Connected to %s", url)

                lock_path = dispatch_path.parent / "lock" if dispatch_path is not None else None

                async def _recv() -> None:
                    async for message in ws:
                        if isinstance(message, bytes):
                            logger.warning("Received unexpected binary frame, ignoring")
                            continue
                        if dispatch_path is not None:
                            while True:
                                try:
                                    locked = (
                                        lock_path.exists() and lock_path.read_text().strip() == "1"
                                    )
                                except FileNotFoundError:
                                    locked = False
                                if not locked:
                                    break
                                await asyncio.sleep(0.5)
                            with dispatch_path.open("a") as fh:
                                fh.write(f"{message}\n")

                async def _send() -> None:
                    while True:
                        line = await queue.get()
                        await ws.send(line)
                        queue.task_done()

                send_task = asyncio.create_task(_send())
                try:
                    await _recv()
                    logger.warning(
                        "Server closed connection, reconnecting in %.1fs…", reconnect_delay
                    )
                finally:
                    send_task.cancel()
                    try:
                        await send_task
                    except (asyncio.CancelledError, ConnectionClosed, Exception):
                        pass

        except asyncio.CancelledError:
            raise
        except InvalidStatus as exc:
            logger.warning(
                "WebSocket handshake failed (%s), refreshing token and retrying in %.1fs…",
                exc.response.status_code,
                reconnect_delay,
            )
            force_refresh = True
        except ConnectionClosed as exc:
            logger.warning("Connection closed (%s), reconnecting in %.1fs…", exc, reconnect_delay)
        except OSError as exc:
            logger.warning("Connection failed (%s), retrying in %.1fs…", exc, reconnect_delay)
        await asyncio.sleep(reconnect_delay)
