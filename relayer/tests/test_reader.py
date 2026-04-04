"""Tests for doom_frequency_relayer.reader"""

import asyncio
from unittest.mock import MagicMock

import pytest

from doom_frequency_relayer.reader import FileWatcher, tail_file


async def test_file_watcher_notifies_on_matching_path(tmp_path):
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[None] = asyncio.Queue()
    path = tmp_path / "output"
    path.touch()

    watcher = FileWatcher(path, queue, loop)
    event = MagicMock()
    event.src_path = str(path)
    watcher.on_modified(event)

    await asyncio.sleep(0)  # let call_soon_threadsafe execute
    assert not queue.empty()


async def test_file_watcher_ignores_other_paths(tmp_path):
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[None] = asyncio.Queue()
    path = tmp_path / "output"
    other = tmp_path / "other"
    path.touch()
    other.touch()

    watcher = FileWatcher(path, queue, loop)
    event = MagicMock()
    event.src_path = str(other)
    watcher.on_modified(event)

    await asyncio.sleep(0)
    assert queue.empty()


async def test_tail_file_not_found(tmp_path):
    queue: asyncio.Queue[str] = asyncio.Queue()
    with pytest.raises(FileNotFoundError):
        await tail_file(tmp_path / "nonexistent", queue)


async def test_tail_file_yields_new_lines(tmp_path):
    output = tmp_path / "output"
    output.write_text("")  # create empty file
    queue: asyncio.Queue[str] = asyncio.Queue()

    task = asyncio.create_task(tail_file(output, queue))
    await asyncio.sleep(0.3)  # give watchdog time to start

    with output.open("a") as fh:
        fh.write("line one\nline two\n")

    line1 = await asyncio.wait_for(queue.get(), timeout=3.0)
    line2 = await asyncio.wait_for(queue.get(), timeout=3.0)

    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task

    assert line1 == "line one"
    assert line2 == "line two"
