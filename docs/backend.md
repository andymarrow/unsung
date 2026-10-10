# Backend setup (the Stage)

The Stage uses [Supabase](https://supabase.com): auth, Postgres and storage. The free tier is enough to start.

1. **Create a project** at supabase.com. Note the project URL and the anon (or publishable) key under *Project Settings → API*. This key is public by design; row-level security protects the data.
2. **Apply the schema**: open *SQL editor*, paste `supabase/migrations/0001_social.sql`, run it. (Or `supabase link` + `supabase db push` with the CLI.) It creates profiles, posts, likes, comments, follows, counters, a `profile_stats` view, the private `takes` storage bucket and all policies.
3. **Email codes**: *Authentication → Email Templates → Magic Link*: include `{{ .Token }}` in the template so users receive a 6-digit code (the app signs in with codes, not links). Example body: `Your Unsung code is {{ .Token }}`.
4. **Build with it**: pass `--dart-define=SUPABASE_URL=…` and `--dart-define=SUPABASE_ANON_KEY=…`, or add both as GitHub repository secrets so CI builds the APK with the Stage switched on.

## What the policies guarantee

- A post with `visibility = 'private'` is readable only by its author: in the table, in likes/comments, and in storage (signed URLs are refused for others).
- Only the author can change a post's caption or visibility, or delete it. Like and comment counts change only through triggers.
- Likes and comments can only be added to public posts.
- Audio files live under `<user id>/` in the private `takes` bucket; uploads outside your own folder are rejected.

## Not included yet

Moderation/reporting, blocking, push notifications and avatar images. Add moderation before opening the Stage to the public.
