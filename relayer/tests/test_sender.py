"""Tests for doom_frequency_relayer.sender"""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from websockets.datastructures import Headers
from websockets.exceptions import ConnectionClosed, InvalidStatus
from websockets.http11 import Response

from doom_frequency_relayer.sender import send_lines


def _make_ws(recv_items=(), *, send_side_effect=None):
    """Build a mock WebSocket with a controlled async iterator for incoming messages."""

    async def _aiter():
        for item in recv_items:
            yield item

    mock_ws = AsyncMock()
    mock_ws.__aiter__ = MagicMock(return_value=_aiter())
    if send_side_effect is not None:
        mock_ws.send.side_effect = send_side_effect
    return mock_ws


def _make_connect(ws):
    """Wrap a mock WebSocket in an async context manager compatible with websockets.connect."""
    cm = AsyncMock()
    cm.__aenter__ = AsyncMock(return_value=ws)
    cm.__aexit__ = AsyncMock(return_value=False)
    return MagicMock(return_value=cm)


async def test_send_lines_sends_from_queue():
    sent: list[str] = []
    done = asyncio.Event()

    async def fake_send(line):
        sent.append(line)
        done.set()

    async def blocking_recv():
        await done.wait()
        return
        yield  # make it an async generator

    mock_ws = AsyncMock()
    mock_ws.send = fake_send
    mock_ws.__aiter__ = MagicMock(return_value=blocking_recv())

    queue: asyncio.Queue[str] = asyncio.Queue()
    await queue.put("hello doom")

    with patch("doom_frequency_relayer.sender.websockets.connect", _make_connect(mock_ws)):
        task = asyncio.create_task(send_lines("ws://test", queue, reconnect_delay=60.0))
        await asyncio.wait_for(done.wait(), timeout=2.0)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    assert sent == ["hello doom"]


async def test_send_lines_writes_dispatch(tmp_path):
    dispatch_file = tmp_path / "dispatch"
    written = asyncio.Event()

    async def recv_with_message():
        yield "doom event: player_died"
        written.set()
        await asyncio.sleep(60)  # block until cancelled

    mock_ws = AsyncMock()
    mock_ws.__aiter__ = MagicMock(return_value=recv_with_message())

    queue: asyncio.Queue[str] = asyncio.Queue()

    with patch("doom_frequency_relayer.sender.websockets.connect", _make_connect(mock_ws)):
        task = asyncio.create_task(
            send_lines("ws://test", queue, dispatch_path=dispatch_file, reconnect_delay=60.0)
        )
        await asyncio.wait_for(written.wait(), timeout=2.0)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    assert dispatch_file.read_text() == "doom event: player_died\n"


async def test_send_lines_sets_auth_header():
    mock_ws = _make_ws()
    token_calls: list[dict] = []

    async def fake_token(*, force_refresh=False):
        token_calls.append({"force_refresh": force_refresh})
        return "bearer-token-xyz"

    connect_mock = MagicMock()
    cm = AsyncMock()
    cm.__aenter__ = AsyncMock(return_value=mock_ws)
    cm.__aexit__ = AsyncMock(return_value=False)
    connect_mock.return_value = cm

    queue: asyncio.Queue[str] = asyncio.Queue()

    with patch("doom_frequency_relayer.sender.websockets.connect", connect_mock):
        task = asyncio.create_task(
            send_lines("ws://test", queue, token_factory=fake_token, reconnect_delay=60.0)
        )
        await asyncio.sleep(0.05)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    _, kwargs = connect_mock.call_args
    assert kwargs["additional_headers"]["Authorization"] == "Bearer bearer-token-xyz"
    assert token_calls[0] == {"force_refresh": False}


async def test_send_lines_force_refresh_on_invalid_status():
    token_calls: list[dict] = []

    async def fake_token(*, force_refresh=False):
        token_calls.append({"force_refresh": force_refresh})
        return "token"

    mock_ws = _make_ws()
    reject_response = Response(401, "Unauthorized", Headers([]))
    connect_call = [0]

    def connect_side_effect(url, **kwargs):
        connect_call[0] += 1
        cm = AsyncMock()
        if connect_call[0] == 1:
            cm.__aenter__ = AsyncMock(side_effect=InvalidStatus(reject_response))
        else:
            cm.__aenter__ = AsyncMock(return_value=mock_ws)
        cm.__aexit__ = AsyncMock(return_value=False)
        return cm

    queue: asyncio.Queue[str] = asyncio.Queue()

    with patch("doom_frequency_relayer.sender.websockets.connect", side_effect=connect_side_effect):
        task = asyncio.create_task(
            send_lines("ws://test", queue, token_factory=fake_token, reconnect_delay=0.01)
        )
        await asyncio.sleep(0.1)  # let first connect fail and second attempt run
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    assert len(token_calls) >= 2
    assert token_calls[0] == {"force_refresh": False}
    assert token_calls[1] == {"force_refresh": True}


async def test_send_lines_reconnects_on_connection_closed():
    connect_count = [0]
    reconnected = asyncio.Event()

    def connect_side_effect(url, **kwargs):
        connect_count[0] += 1
        if connect_count[0] == 2:
            reconnected.set()
        cm = AsyncMock()
        cm.__aenter__ = AsyncMock(side_effect=ConnectionClosed(None, None))
        cm.__aexit__ = AsyncMock(return_value=False)
        return cm

    queue: asyncio.Queue[str] = asyncio.Queue()

    with patch("doom_frequency_relayer.sender.websockets.connect", side_effect=connect_side_effect):
        task = asyncio.create_task(send_lines("ws://test", queue, reconnect_delay=0.01))
        await asyncio.wait_for(reconnected.wait(), timeout=2.0)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    assert connect_count[0] >= 2
