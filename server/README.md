# Studio separation server (optional)

Unsung's **Quick** mode removes vocals on the phone. **Studio** mode sends the song to this server, which uses [Demucs](https://github.com/facebookresearch/demucs) (MIT) to separate the vocals with machine learning, and returns a much cleaner instrumental.

```bash
docker build -t unsung-separation .
docker run -p 8000:8000 unsung-separation
curl -F file=@song.mp3 http://localhost:8000/separate -o instrumental.m4a
```

Then build the app with `--dart-define=SEPARATION_API_URL=https://your-host` (or set the `SEPARATION_API_URL` GitHub secret so CI bakes it in). The Studio option only appears when this is set.

Notes:
- CPU works but takes roughly the song's length; a small GPU makes it a few seconds.
- Uploaded files are deleted after each request. Add authentication (e.g. an API gateway key) before exposing it publicly.
- Users must have the right to process the songs they upload.
