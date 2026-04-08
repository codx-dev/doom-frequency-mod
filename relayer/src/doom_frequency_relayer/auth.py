"""DoomFrequency API key → JWT authentication."""

import os

import httpx

AUTH_URL = "https://doomfrequency.fm/pub/jwt"


class MissingCredentialsError(RuntimeError):
    pass


def get_api_key() -> str:
    """Read DOOMFREQUENCY_API_KEY from the environment."""
    key = os.environ.get("DOOMFREQUENCY_API_KEY")
    if not key:
        raise MissingCredentialsError(
            "Missing required environment variable: DOOMFREQUENCY_API_KEY"
        )
    return key


async def fetch_jwt(api_key: str) -> str:
    """POST *api_key* to AUTH_URL and return the JWT token string."""
    async with httpx.AsyncClient() as client:
        response = await client.post(AUTH_URL, json={"api_key": api_key})
        response.raise_for_status()
        return response.json()["token"]
