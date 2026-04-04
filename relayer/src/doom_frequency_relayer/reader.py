"""File reader with tail-like watching capability."""

import asyncio
from pathlib import Path

from watchdog.events import FileModifiedEvent, FileSystemEventHandler
from watchdog.observers import Observer


class FileWatcher(FileSystemEventHandler):
    """Watches a file for modifications and pushes new lines to a queue."""

    def __init__(
        self, path: Path, queue: asyncio.Queue[None], loop: asyncio.AbstractEventLoop
    ) -> None:
        self._path = path
        self._queue = queue
        self._loop = loop

    def on_modified(self, event: FileModifiedEvent) -> None:
        if Path(event.src_path).resolve() == self._path.resolve():
            self._loop.call_soon_threadsafe(self._queue.put_nowait, None)


OUTPUT = "output"


async def tail_file(path: Path, queue: asyncio.Queue[str]) -> None:
    """Read a file from the end and emit new lines as they are appended."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(path)

    loop = asyncio.get_running_loop()
    notify_queue: asyncio.Queue[None] = asyncio.Queue()
    handler = FileWatcher(path, notify_queue, loop)
    observer = Observer()
    observer.schedule(handler, str(path.parent), recursive=False)
    observer.start()

    try:
        with path.open() as fh:
            fh.seek(0, 2)  # seek to end
            while True:
                await notify_queue.get()
                while line := fh.readline():
                    stripped = line.rstrip("\n")
                    if stripped:
                        await queue.put(stripped)
    finally:
        observer.stop()
        await asyncio.get_running_loop().run_in_executor(None, lambda: observer.join(timeout=5))
