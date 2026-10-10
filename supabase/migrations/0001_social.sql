-- Unsung social schema. Apply with the Supabase CLI (`supabase db push`) or
-- paste into the SQL editor. Row-level security enforces private/public.

create extension if not exists pgcrypto;

-- Profiles ------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text not null unique check (handle ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null default '' check (char_length(display_name) <= 48),
  bio text not null default '' check (char_length(bio) <= 160),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
create policy "profiles are public" on public.profiles for select using (true);
create policy "edit own profile" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);
revoke update on public.profiles from authenticated, anon;
grant update (handle, display_name, bio) on public.profiles to authenticated;

-- New users get a profile with a unique handle derived from their email.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  base text := regexp_replace(lower(split_part(new.email, '@', 1)), '[^a-z0-9_]', '', 'g');
  candidate text;
begin
  if char_length(base) < 3 then base := 'singer'; end if;
  base := left(base, 18);
  candidate := base;
  while exists (select 1 from public.profiles where handle = candidate) loop
    candidate := base || '_' || substr(md5(random()::text), 1, 4);
  end loop;
  insert into public.profiles (id, handle, display_name) values (new.id, candidate, base);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Posts (shared takes) --------------------------------------------------------
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  song_title text not null check (char_length(song_title) <= 200),
  artist text check (char_length(artist) <= 200),
  caption text not null default '' check (char_length(caption) <= 280),
  audio_path text not null,
  duration_ms integer not null check (duration_ms > 0),
  peaks jsonb not null default '[]',
  in_tune real not null default 0 check (in_tune between 0 and 1),
  visibility text not null default 'private' check (visibility in ('private', 'public')),
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index posts_public_recent on public.posts (created_at desc) where visibility = 'public';
create index posts_author on public.posts (author_id, created_at desc);

alter table public.posts enable row level security;
create policy "see public posts and your own" on public.posts for select
  using (visibility = 'public' or author_id = auth.uid());
create policy "create own posts" on public.posts for insert
  with check (author_id = auth.uid());
create policy "update own posts" on public.posts for update
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "delete own posts" on public.posts for delete
  using (author_id = auth.uid());

-- Owners may only edit caption and visibility; counters change through the
-- triggers below.
revoke update on public.posts from authenticated, anon;
grant update (caption, visibility) on public.posts to authenticated;

-- Likes -------------------------------------------------------------------------
create table public.likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.likes enable row level security;
create policy "likes on visible posts are visible" on public.likes for select
  using (exists (select 1 from public.posts p where p.id = post_id
                 and (p.visibility = 'public' or p.author_id = auth.uid())));
create policy "like public posts" on public.likes for insert
  with check (user_id = auth.uid() and exists (
    select 1 from public.posts p where p.id = post_id and p.visibility = 'public'));
create policy "unlike" on public.likes for delete using (user_id = auth.uid());

-- Comments ----------------------------------------------------------------------
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create index comments_post on public.comments (post_id, created_at);

alter table public.comments enable row level security;
create policy "comments on visible posts are visible" on public.comments for select
  using (exists (select 1 from public.posts p where p.id = post_id
                 and (p.visibility = 'public' or p.author_id = auth.uid())));
create policy "comment on public posts" on public.comments for insert
  with check (author_id = auth.uid() and exists (
    select 1 from public.posts p where p.id = post_id and p.visibility = 'public'));
create policy "delete own comments" on public.comments for delete
  using (author_id = auth.uid());

-- Follows -----------------------------------------------------------------------
create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

alter table public.follows enable row level security;
create policy "follows are public" on public.follows for select using (true);
create policy "follow" on public.follows for insert with check (follower_id = auth.uid());
create policy "unfollow" on public.follows for delete using (follower_id = auth.uid());

-- Counter triggers ----------------------------------------------------------------
create or replace function public.bump_counts() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'likes' then
    update posts set like_count = like_count + (case when tg_op = 'INSERT' then 1 else -1 end)
      where id = coalesce(new.post_id, old.post_id);
  else
    update posts set comment_count = comment_count + (case when tg_op = 'INSERT' then 1 else -1 end)
      where id = coalesce(new.post_id, old.post_id);
  end if;
  return null;
end $$;

create trigger likes_count after insert or delete on public.likes
  for each row execute function public.bump_counts();
create trigger comments_count after insert or delete on public.comments
  for each row execute function public.bump_counts();

-- Profile stats -----------------------------------------------------------------
create or replace view public.profile_stats with (security_invoker = true) as
select
  p.id,
  (select count(*) from public.posts x where x.author_id = p.id and x.visibility = 'public') as public_posts,
  (select coalesce(sum(x.like_count), 0) from public.posts x where x.author_id = p.id and x.visibility = 'public') as likes_received,
  (select count(*) from public.follows f where f.followee_id = p.id) as followers,
  (select count(*) from public.follows f where f.follower_id = p.id) as following
from public.profiles p;

-- Storage: take audio. Private bucket; files live under <user id>/.
insert into storage.buckets (id, name, public) values ('takes', 'takes', false)
  on conflict (id) do nothing;

create policy "upload own takes" on storage.objects for insert
  with check (bucket_id = 'takes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "delete own takes" on storage.objects for delete
  using (bucket_id = 'takes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "read own or public takes" on storage.objects for select
  using (bucket_id = 'takes' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (select 1 from public.posts p where p.audio_path = name and p.visibility = 'public')
  ));
