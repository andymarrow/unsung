# Design brief: Unsung

**Category / audience / core loop:** Personal karaoke + social singing. For people who already own the songs they love (phone library) and want to sing them, keep the takes, and share the good ones.
Core loop: **pick a song from your library → unsing it (remove the vocals) → sing over it with live lyrics and pitch → polish the take → keep private or go public → others listen and like.**

## Mood
Backstage after dark. Warm, tactile, confident, a little analogue.

## Direction chosen (and why)
**"Spotlight & Tape."** A warm near-black stage, one hot signal-orange accent used like a spotlight (only on what matters right now), engineered monospaced labels like a tape machine, and big, expressive variable-font lyrics that physically *breathe* as you sing.

Why: every competitor in this category (social karaoke apps) lands on the same purple-to-pink neon gradient with glossy stars and bokeh. That is the gap. Unsung goes the other way: restraint, warmth, one colour, and typography doing the emotional work. It also suits the product's honesty: your library, your voice, no locked songs.

Alternatives considered:
- *Liquid glass everywhere* (translucent layered panels, as some karaoke apps moved to in 2025/26). Pretty, but becomes noise behind fast-moving lyrics. We keep glass **only** for transient layers (mini player, sheets), following the "surgical glass" trend.
- *Neon club* (magenta/cyan glow). Rejected as the generic default of the category.

## Colour (light and dark)
Dark is the primary experience (singing happens at night, OLED-friendly). Light is fully implemented.

| Token | Hex (light) | Hex (dark) | Role | Contrast check |
|---|---|---|---|---|
| stage | #F4EEE6 | #0F0D0C | page background | — |
| surface | #FBF8F3 | #1A1716 | cards, rows | — |
| raised | #EAE2D6 | #24201E | chips, inputs, pressed | — |
| ink | #161311 | #F4EEE6 | primary text | 16.1 / 16.8 ✅ |
| inkMuted | #5E5650 | #A8A09A | secondary text | 6.2 / 7.5 ✅ (6.3 on raised) |
| inkFaint | #8F8780 | #6E6661 | sung lyrics, disabled, large text only | 3.1 / 3.5 ✅ large only |
| cue (accent) | #B0380B | #FF5B24 | the spotlight: active lyric, record, primary CTA | 5.3 / 6.3 ✅ |
| onCue | #FFFFFF | #0F0D0C | text on accent | 6.1 / 6.3 ✅ |
| tune | #0E8A4F | #5BF0A0 | "on pitch" signal, graphics only | 3.8 / 13.3 ✅ (non-text 3:1) |
| hairline | ink @ 10% | ink @ 10% | 1px dividers | decorative |

Rule: **one accent**. `tune` exists only inside the pitch ribbon.

## Typography
Two open-licence (SIL OFL 1.1) variable families, bundled in `assets/fonts` with their licences:
- **Bricolage Grotesque** (opsz 12–96, wdth 75–100, wght 200–800): display, titles, lyrics, body.
- **JetBrains Mono** (wght 100–800): labels, numerals, timecodes, metadata. Uppercase labels with +12% tracking.

| Style | Family | Size | Weight | wdth | Tracking | Line height |
|---|---|---|---|---|---|---|
| hero | Bricolage | 56 | 800 | 78 | -2% | 0.95 |
| title | Bricolage | 32 | 700 | 85 | -1% | 1.05 |
| heading | Bricolage | 22 | 650 | 90 | 0 | 1.15 |
| lyricActive | Bricolage | 34 | 750 | 82→100 animated | -1% | 1.1 |
| lyricNext | Bricolage | 26 | 600 | 90 | 0 | 1.15 |
| body | Bricolage | 16 | 420 | 100 | 0 | 1.45 |
| label | JetBrains Mono | 11 | 600 | — | +12%, uppercase | 1.2 |
| numeral | JetBrains Mono | 13 | 500 | — | 0, tabular | 1.2 |

## Spacing, radii, shadows
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64. Page gutter 20.
- Radii: 6 (chips), 14 (cards), 28 (sheets), full (record button, avatars). Square-cornered "tape labels" (radius 2) for metadata tags, an intentional contrast.
- No drop shadows on dark. Depth comes from surface steps and the cue glow (a soft radial cue light, 24% alpha) behind the one focal element.

## Navigation model and key screens
Bottom bar with 3 destinations + a central record affordance: **Library**, **Stage** (social feed), **Me** (profile + takes). Studio and Player are full-screen pushes.

1. **Onboarding** – 3 beats, asks for audio + mic permissions with reasons, at the moment they're needed.
2. **Library** – every song on the device, search, filter (All / Karaoke-ready), alphabet scrub. Each row shows a tape-label tag `READY` once unsung.
3. **Song sheet** – artwork, metadata, "Unsing this song" with Quick (on-device) / Studio (server, if configured) choice.
4. **Player / Rehearse** – instrumental with live lyrics, vocal guide fader (original ↔ instrumental), key ±6, lyrics offset.
5. **Studio** – record over the instrumental, live lyrics + pitch ribbon, headphone hint, countdown.
6. **Take review** – re-mix non-destructively: vocal level, reverb, echo, sync nudge, key. Save private / publish.
7. **Stage (feed)** – public takes, For you / Following, like, comment, follow.
8. **Profile** – avatar, bio, stats (takes, likes, followers), grid of takes; own private takes marked with a lock.
9. **Take detail** – waveform scrubber, like, comments, visibility toggle (owner).

## Signature moments
1. **The Unsinging.** When a song is converted, its waveform splits in two: the vocal band lifts off as a glowing cue-coloured ribbon and dissolves upward, the instrumental settles down as a solid tape-grey waveform. Driven by real progress from the native converter. Trigger: tap "Unsing". Duration: progress-driven, with a 600ms emphasized settle at completion. Verified by golden frames of the painter at 0/50/100%.
2. **Breathing lyrics.** The active line fills left-to-right with cue in sync with the music (line-timed LRC, word-timed if available) while its `wdth` axis expands 82→100 and weight eases up: the words physically open as they are sung. Upcoming line is larger and brighter than past lines (past lines fade to inkFaint). Scroll uses a 420ms decelerate curve. Reduce-motion: no width animation, colour fill only.
3. **The Spotlight.** Pressing the record button throws a radial cue light that expands from the button to fill the screen and reveals the Studio (circular clip reveal, 600ms emphasized), with a heavy haptic on "3-2-1-sing". Going public on a take flips the lock into a broadcast mark with a ripple (280ms).

## Motion language
- fast 140ms / base 240ms / slow 420ms / signature 650ms.
- Curves: standard `Cubic(0.2, 0, 0, 1)`, emphasized overshoot `Cubic(0.34, 1.4, 0.64, 1)`, decelerate `Cubic(0, 0, 0, 1)`.
- Press feedback everywhere: scale to 0.96 over fast, standard curve, plus selection haptic on toggles.
- Staggered list entrances: 30ms per item, capped at 8 items.
- All motion respects `MediaQuery.disableAnimations`.

## Borrowed from house style / changed for this app
House style not learned yet (`house-style.md` is empty). Designed from this brief; the user can ask App Studio to learn their style from their repos later.

## Inspiration consulted
| Source (link) | Principle taken |
|---|---|
| [KaraFun – Liquid Glass redesign](https://karafun.com/blog/1650-sing-in-style-with-the-new-liquid-glass-design.html) | Depth and atmosphere over flat panels; keep focus on the singer; visuals that follow the mood of the song. We limit glass to transient layers. |
| [Stingray Karaoke design guidelines](https://karaoke-api-doc.stingray.com/docs/introduction/design-guidelines) | Upcoming lyrics more prominent than past ones; high contrast; legible, non-decorative lyric type; keep animation out of the lyric safe zone. |
| [Apple Music Sing (MusicRadar)](https://musicradar.com/news/apple-music-sing-vocal-removal) | One simple vocal fader instead of an on/off; lyrics that move with the vocal; duet/backing parts visually separated. |
| [Teenage Engineering design analysis](https://blakecrosley.com/es/guides/design/teenage-engineering) (outside category) | One confident orange, monospaced uppercase labels with wide tracking, tabular numerals, functional graphics that show real audio state (waveforms, meters). |
| [Smule user feedback analysis](https://kimola.com/reports/unlock-smule-app-insights-from-user-feedback-to-future-strategies-google-play-en-us-145145) | Pain points to beat: locked song catalogues, hard uploads, effects frozen after recording. Unsung uses your own library and keeps effects editable forever. |
| [2026 mobile UI trends (VP0)](https://vp0.com/blogs/mobile-app-ui-design-inspiration-2026) | Thumb-zone primary actions, bottom sheets, deliberate dark mode, glass only on temporary layers, functional micro-interactions with haptics. |

No images, logos or layouts were copied; only principles.

## Assumptions
- Android first (APK). Flutter, Riverpod, go_router.
- Lyrics from LRCLIB (free, open, no key) when online; manual .lrc import otherwise.
- Social backend: Supabase (auth, Postgres with row-level security for private/public, storage). Runs offline-first without it.
