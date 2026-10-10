"""Unsung Studio server.

POST /separate with a multipart `file` (any audio) -> returns the
instrumental (everything except vocals) as AAC in an .m4a container.

GET /link?url=...        -> metadata for a YouTube link (title, artist, length)
GET /link/audio?url=...  -> the link's audio as AAC in an .m4a container

Uses Demucs (htdemucs, two-stem "vocals") for ML source separation. Runs on
CPU (slow, ~1x realtime) or GPU (fast). Optional: the app works without it
using on-device Quick mode.
"""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse

from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

MAX_BYTES = int(os.environ.get("MAX_UPLOAD_MB", "40")) * 1024 * 1024
MODEL = os.environ.get("DEMUCS_MODEL", "htdemucs")

# Links: only YouTube hosts, so the server is never an open download proxy.
LINK_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"}
MAX_LINK_SECONDS = int(os.environ.get("MAX_LINK_MINUTES", "15")) * 60
# Optional proof-of-origin token provider (bgutil-ytdlp-pot-provider), e.g.
# http://pot:4416 in docker compose. Without it most links still work.
POT_PROVIDER_URL = os.environ.get("POT_PROVIDER_URL", "")

app = FastAPI(title="Unsung separation")


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL}


@app.post("/separate")
async def separate(file: UploadFile = File(...)):
    work = Path(tempfile.mkdtemp(prefix="unsung-"))
    try:
        src = work / "input"
        size = 0
        with src.open("wb") as out:
            while chunk := await file.read(1 << 20):
                size += len(chunk)
                if size > MAX_BYTES:
                    raise HTTPException(413, "File too large")
                out.write(chunk)
        run = subprocess.run(
            ["python", "-m", "demucs", "--two-stems", "vocals", "-n", MODEL, "-o", str(work / "out"), str(src)],
            capture_output=True,
            text=True,
            timeout=900,
        )
        if run.returncode != 0:
            raise HTTPException(422, "Could not separate this file")
        stem = next((work / "out").rglob("no_vocals.wav"), None)
        if stem is None:
            raise HTTPException(500, "Separation produced no output")
        m4a = work / "instrumental.m4a"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(stem), "-c:a", "aac", "-b:a", "192k", str(m4a)],
            check=True,
            timeout=300,
        )
        return FileResponse(
            m4a,
            media_type="audio/mp4",
            filename="instrumental.m4a",
            background=BackgroundTask(shutil.rmtree, work, ignore_errors=True),
        )
    except HTTPException:
        shutil.rmtree(work, ignore_errors=True)
        raise
    except Exception:
        shutil.rmtree(work, ignore_errors=True)
        raise HTTPException(500, "Separation failed")


def _check_link(url: str) -> str:
    try:
        parsed = urlparse(url.strip())
    except ValueError:
        raise HTTPException(400, "That doesn't look like a link")
    if parsed.scheme not in ("http", "https") or (parsed.hostname or "").lower() not in LINK_HOSTS:
        raise HTTPException(400, "Only YouTube links are supported")
    return url.strip()


def _ydl_options(**extra):
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "format": "bestaudio[ext=m4a]/bestaudio/best",
    }
    if POT_PROVIDER_URL:
        opts["extractor_args"] = {"youtubepot-bgutilhttp": {"base_url": [POT_PROVIDER_URL]}}
    opts.update(extra)
    return opts


def _info(url: str) -> dict:
    import yt_dlp  # imported lazily so /separate works without it

    try:
        with yt_dlp.YoutubeDL(_ydl_options()) as ydl:
            info = ydl.extract_info(url, download=False)
    except yt_dlp.utils.DownloadError as e:
        message = str(e).lower()
        if "private" in message or "unavailable" in message:
            raise HTTPException(404, "This video is private or unavailable")
        if "sign in" in message or "age" in message:
            raise HTTPException(403, "YouTube wants a sign-in for this one")
        raise HTTPException(422, "Couldn't read this link")
    if info.get("_type") == "playlist":
        raise HTTPException(400, "That's a playlist. Paste a single song")
    if info.get("is_live"):
        raise HTTPException(400, "Live streams can't be turned into karaoke")
    duration = int(info.get("duration") or 0)
    if duration > MAX_LINK_SECONDS:
        raise HTTPException(413, f"Songs up to {MAX_LINK_SECONDS // 60} minutes only")
    return info


def _meta(info: dict) -> dict:
    return {
        "id": info.get("id"),
        "title": info.get("track") or info.get("title") or "Untitled",
        "artist": info.get("artist") or info.get("uploader") or info.get("channel"),
        "durationMs": int(info.get("duration") or 0) * 1000,
        "thumbnail": info.get("thumbnail"),
    }


@app.get("/link")
def link(url: str = Query(..., max_length=500)):
    return _meta(_info(_check_link(url)))


@app.get("/link/audio")
def link_audio(url: str = Query(..., max_length=500)):
    import yt_dlp

    url = _check_link(url)
    _info(url)  # same checks (length, live, playlist) before downloading
    work = Path(tempfile.mkdtemp(prefix="unsung-link-"))
    try:
        opts = _ydl_options(
            outtmpl=str(work / "audio.%(ext)s"),
            postprocessors=[{"key": "FFmpegExtractAudio", "preferredcodec": "m4a"}],
        )
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])
        out = next(work.glob("audio.m4a"), None)
        if out is None:
            raise HTTPException(500, "Download produced no audio")
        return FileResponse(
            out,
            media_type="audio/mp4",
            filename="audio.m4a",
            background=BackgroundTask(shutil.rmtree, work, ignore_errors=True),
        )
    except HTTPException:
        shutil.rmtree(work, ignore_errors=True)
        raise
    except Exception:
        shutil.rmtree(work, ignore_errors=True)
        raise HTTPException(502, "Couldn't download this link")
