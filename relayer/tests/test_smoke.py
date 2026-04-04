"""Smoke tests — verify the package imports and basic wiring."""

from doom_frequency_relayer.reader import tail_file
from doom_frequency_relayer.relayer import run
from doom_frequency_relayer.sender import send_lines


def test_imports() -> None:
    assert callable(run)
    assert callable(tail_file)
    assert callable(send_lines)
