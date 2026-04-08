"""Tests for doom_frequency_relayer.auth"""

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

from doom_frequency_relayer.auth import MissingCredentialsError, fetch_jwt, get_api_key


def test_get_api_key_missing(monkeypatch):
    monkeypatch.delenv("DOOMFREQUENCY_API_KEY", raising=False)
    with pytest.raises(MissingCredentialsError):
        get_api_key()


def test_get_api_key_returns_value(monkeypatch):
    monkeypatch.setenv("DOOMFREQUENCY_API_KEY", "test-key-123")
    assert get_api_key() == "test-key-123"


async def test_fetch_jwt_success():
    mock_response = MagicMock()
    mock_response.json.return_value = {"token": "jwt-abc-123"}

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.post = AsyncMock(return_value=mock_response)

    with patch("doom_frequency_relayer.auth.httpx.AsyncClient", return_value=mock_client):
        token = await fetch_jwt("my-api-key")

    assert token == "jwt-abc-123"
    mock_client.post.assert_called_once_with(
        "https://doomfrequency.fm/pub/jwt", json={"api_key": "my-api-key"}
    )


async def test_fetch_jwt_http_error():
    mock_request = MagicMock()
    mock_err_response = MagicMock()
    mock_response = MagicMock()
    mock_response.raise_for_status.side_effect = httpx.HTTPStatusError(
        "401 Unauthorized", request=mock_request, response=mock_err_response
    )

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.post = AsyncMock(return_value=mock_response)

    with patch("doom_frequency_relayer.auth.httpx.AsyncClient", return_value=mock_client):
        with pytest.raises(httpx.HTTPStatusError):
            await fetch_jwt("bad-key")
