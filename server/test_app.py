"""Tests for the link endpoints. yt-dlp is faked: no network needed.

    pip install -r requirements.txt httpx pytest && pytest
"""
from pathlib import Path

import pytest
import yt_dlp
from fastapi.testclient import TestClient

import app as server

client = TestClient(server.app)

SONG = {
    "id": "abc123",
    "title": "Paper Moons (Official Video)",
    "track": "Paper Moons",
    "artist": "The Lanterns",
    "uploader": "LanternsVEVO",
    "duration": 214,
    "thumbnail": "https://i.ytimg.com/vi/abc123/hq.jpg",
}


class FakeYDL:
    info = SONG
    error = None

    def __init__(self, opts):
        self.opts = opts

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def extract_info(self, url, download=False):
        if FakeYDL.error:
            raise yt_dlp.utils.DownloadError(FakeYDL.error)
        return FakeYDL.info

    def download(self, urls):
        out = Path(self.opts["outtmpl"].replace("%(ext)s", "m4a"))
        out.write_bytes(b"fake m4a")


@pytest.fixture(autouse=True)
def fake_ydl(monkeypatch):
    FakeYDL.info = SONG
    FakeYDL.error = None
    monkeypatch.setattr(yt_dlp, "YoutubeDL", FakeYDL)


def test_link_metadata_prefers_track_and_artist():
    r = client.get("/link", params={"url": "https://youtu.be/abc123"})
    assert r.status_code == 200
    assert r.json() == {
        "id": "abc123",
        "title": "Paper Moons",
        "artist": "The Lanterns",
        "durationMs": 214000,
        "thumbnail": "https://i.ytimg.com/vi/abc123/hq.jpg",
    }


@pytest.mark.parametrize(
    "url",
    ["https://example.com/watch?v=abc", "file:///etc/passwd", "http://169.254.169.254/", "not a link"],
)
def test_only_youtube_hosts(url):
    assert client.get("/link", params={"url": url}).status_code == 400


def test_rejects_long_live_and_playlists():
    FakeYDL.info = {**SONG, "duration": 60 * 60}
    assert client.get("/link", params={"url": "https://youtu.be/x"}).status_code == 413
    FakeYDL.info = {**SONG, "is_live": True}
    assert client.get("/link", params={"url": "https://youtu.be/x"}).status_code == 400
    FakeYDL.info = {"_type": "playlist"}
    assert client.get("/link", params={"url": "https://youtu.be/x"}).status_code == 400


def test_private_video_is_404():
    FakeYDL.error = "ERROR: Private video"
    assert client.get("/link", params={"url": "https://youtu.be/x"}).status_code == 404


def test_audio_download_returns_m4a():
    r = client.get("/link/audio", params={"url": "https://www.youtube.com/watch?v=abc123"})
    assert r.status_code == 200
    assert r.headers["content-type"] == "audio/mp4"
    assert r.content == b"fake m4a"
