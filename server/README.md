# Studio separation server (optional)

Unsung's **Quick** mode removes vocals on the phone. **Studio** mode sends the song to this server, which uses [Demucs](https://github.com/facebookresearch/demucs) (MIT) to separate the vocals with machine learning, and returns a much cleaner instrumental.

```bash
docker build -t unsung-separation .
docker run -p 8000:8000 unsung-separation
curl -F file=@song.mp3 http://localhost:8000/separate -o instrumental.m4a
```

It also powers **link import**: `GET /link?url=…` returns a YouTube link's title, artist and length, and `GET /link/audio?url=…` returns its audio as `.m4a`, using [yt-dlp](https://github.com/yt-dlp/yt-dlp) with [Deno](https://deno.com) for YouTube's player challenges. Only YouTube hosts are accepted (it is never an open download proxy), songs are capped at 15 minutes (`MAX_LINK_MINUTES`), and playlists and live streams are refused.

For the most reliable link import, run it with the proof-of-origin token provider:

```bash
docker compose up -d      # studio server on :8000 + bgutil PO-token provider
pip install -r requirements.txt httpx pytest && pytest   # tests (yt-dlp is mocked)
```

YouTube changes often and yt-dlp keeps up: rebuild the image (`docker compose build --pull`) every few weeks.

Then build the app with `--dart-define=SEPARATION_API_URL=https://your-host` (or set the `SEPARATION_API_URL` GitHub secret so CI bakes it in). The Studio option only appears when this is set.

Notes:
- CPU works but takes roughly the song's length; a small GPU makes it a few seconds.
- Uploaded files are deleted after each request. Add authentication (e.g. an API gateway key) before exposing it publicly.
- Users must have the right to process the songs they upload.
