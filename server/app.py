"""Unsung Studio separation server.

POST /separate with a multipart `file` (any audio) -> returns the
instrumental (everything except vocals) as AAC in an .m4a container.

Uses Demucs (htdemucs, two-stem "vocals") for ML source separation. Runs on
CPU (slow, ~1x realtime) or GPU (fast). Optional: the app works without it
using on-device Quick mode.
"""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

MAX_BYTES = int(os.environ.get("MAX_UPLOAD_MB", "40")) * 1024 * 1024
MODEL = os.environ.get("DEMUCS_MODEL", "htdemucs")

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
