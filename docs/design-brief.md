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
Dark is the primary experience (singing happens at night, OLED-friendly). Light is fully implemented. Since v0.3.2 the greys are neutral graphite (no warm cast), so the cue is the only colour on screen.

| Token | Hex (light) | Hex (dark) | Role | Contrast check |
|---|---|---|---|---|
| stage | #F6F5F3 | #0D0D0E | page background | — |
| surface | #FFFFFF | #17171A | cards, rows | — |
| raised | #EDECE9 | #222226 | chips, inputs, pressed | — |
| ink | #141415 | #F2F2F0 | primary text | 16.9 / 17.3 ✅ |
| inkMuted | #66666C | #9D9DA3 | secondary text | 5.2 / 7.2 ✅ (4.8 / 5.9 on raised) |
| inkFaint | #85858B | #64646A | sung lyrics, disabled, large text only | 3.4 / 3.3 ✅ large only |
| cue (accent) | #C2410C | #FF5B24 | the spotlight: active lyric, record, primary CTA | 4.8 / 6.3 ✅ |
| onCue | #FFFFFF | #0D0D0E | text on accent | 5.2 / 6.3 ✅ |
| tune | #0E8A4F | #5BF0A0 | "on pitch" signal, graphics only | 4.0 / 13.3 ✅ (non-text 3:1) |
| hairline | ink @ 8% | ink @ 9% | 1px borders on cards, chips, inputs | decorative |

Rule: **one accent**. `tune` exists only inside the pitch ribbon.

## Typography
Two open-licence (SIL OFL 1.1) variable families, bundled in `assets/fonts` with their licences:
- **Bricolage Grotesque** (opsz 12–96, wdth 75–100, wght 200–800): display, titles, lyrics, body.
- **JetBrains Mono** (wght 100–800): labels, numerals, timecodes, metadata. Uppercase labels with +12% tracking.

| Style | Family | Size | Weight | wdth | Tracking | Line height |
|---|---|---|---|---|---|---|
| hero | Bricolage | 48 | 760 | 86 | -2.5% | 1.0 |
| title | Bricolage | 30 | 700 | 94 | -2% | 1.1 |
| heading | Bricolage | 20 | 640 | 100 | -1% | 1.2 |
| section | Bricolage | 17 | 640 | 100 | -0.5% | 1.25 |
| lyricActive | Bricolage | 34 | 740 | 82→100 animated | -1.5% | 1.1 |
| lyricNext | Bricolage | 26 | 620 | 92 | -1% | 1.15 |
| body | Bricolage | 16 | 420 | 100 | 0 | 1.45 |
| rowTitle | Bricolage | 16 | 600 | 100 | -0.5% | 1.25 |
| button / chip | Bricolage | 15 / 13.5 | 640 | 100 | 0, sentence case | 1.2 |
| label | JetBrains Mono | 10.5 | 560 | — | +8%, uppercase | 1.2 |
| numeral | JetBrains Mono | 13 | 500 | — | 0, tabular | 1.2 |

v0.3.2: buttons, chips, tab labels and section titles moved from uppercase mono to sentence-case Bricolage. Mono is kept for metadata only (counts, durations, READY / PRIVATE tags, timecodes), so it reads as the tape-machine detail rather than the main voice.

## Spacing, radii, shadows
- Spacing: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64. Page gutter 20.
- Radii: 12 (row artwork), 20 (cards, sheet artwork), 28 (sheets), full (buttons, chips, search, Sing, avatars). Near-square "tape labels" (radius 3) for metadata tags, an intentional contrast.
- No drop shadows, no glows. Depth comes from one surface step and a hairline border.

## Navigation model and key screens
Bottom bar with 4 destinations around a central Sing affordance: **Library**, **Stage** (social feed) | Sing | **Takes**, **Me**. Studio and Player are full-screen pushes.

*Changed from the first draft (3 destinations, takes inside Me):* takes are the thing people come back to most after singing, and burying them under a profile that only exists once you sign in to the Stage made them hard to find offline. Two tabs either side also balance the bar around Sing. Tabs cross-fade (240ms, with a 1.5% settle) and keep their state.

1. **Onboarding** – 3 beats, asks for audio + mic permissions with reasons, at the moment they're needed.
2. **Library** – every song on the device plus songs brought in from links, search, filter (All / Karaoke-ready), alphabet scrub. `READY` sits on a row's meta line once unsung.
2b. **From a link** (glass sheet) – paste a YouTube or YouTube Music link, or Share → Unsung from the YouTube app. A preview card (thumbnail, cleaned title, artist, length) appears with a breathing skeleton while it resolves; "Bring it in" runs a thin cue progress line along the card's edge; done hands straight to Unsing it.
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

## Launch (v0.3)
Built on what the best launch sequences share (Airbnb's self-drawing Bélo, Headspace's morphs, Apple's content-first launch screens): the first frame is the system splash, one hero motion is made from the brand itself, type arrives with intent, and the exit becomes the first screen. Under two seconds, never waiting on work.

The Unsung story, 1.75s + a 420ms dissolve: the U mark's cue underline wakes into a waveform → the U breathes open on the width axis and "nsung" opens beside it letter by letter → the voice lifts out of the waveform as a cue ribbon while the bars settle to tape grey → the bars close into one cue line under the whole word (dropping to clear the g) and the tagline arrives → it swells slightly and dissolves into the Library, whose ambient light is the same light. Tap to skip; reduce-motion shows the lockup and fades. Native splash (all Android versions) draws the mark at 288dp so the hand-off frame is identical. No light effects: the backdrop is the app's own.

## Surfaces (v0.3.1): neutral, accent-only colour
Owner direction: colour is an accent, never a background; no glows, no shadows, nothing floats.
- **Backdrop**: the flat stage colour (warm near-black / neutral off-white `#F5F4F1`) with a static film grain at 3.5–5%, so big areas read as matte paper rather than a flat fill.
- **Cue orange** only marks action and state: primary buttons, the Sing button, READY tags, the active lyric, progress, the active tab's short underline.
- **Surfaces**: cards are `surface` with a hairline border. Frost (backdrop blur over a translucent fill) is used only where a layer sits over scrolling content: the docked tab bar and sheets, each with a hairline edge.
- **Tab bar**: docked to the bottom edge, full width, hairline on top. No floating capsule, no sliding lens.
- **No** glow, drop shadow, coloured gradient or ambient light anywhere, including the Spotlight (a clean circular reveal), the record button, the pitch ribbon, the Unsinging ribbon and the splash.

## Clean & premium (v0.3.2)
From the owner's references (see Inspiration): the same neutral rules, tightened.
- **One lit choice per decision.** Paired actions are equal-sized pills side by side (Sing | Rehearse); only one is cue. Secondary is a neutral raised pill, not a ghost.
- **Pills everywhere you touch:** search field, filter chips (resting = hairline outline, selected = ink fill), buttons, the round Sing key in the bar.
- **Quiet meta lines.** One muted line ("3:34 · IN TUNE 78% · NOT MIXED YET") instead of a row of boxed tags; boxes are kept for state (READY, ON STAGE, PRIVATE).
- **Section titles in sentence case** with a small mono hint on the right ("Start with a classic — FROM YOUTUBE").
- **Generous card padding** (20) and larger corner radii; header icon buttons are surface discs with a hairline ring.
- Rejected from the references: floating pill tab bars, gradient buttons, product drop shadows, full-bleed orange screens.

## Loading
- Skeletons shimmer with one shared band of light that crosses the whole screen, not per block.
- Anything waiting on music (library scan, lyrics lookup, link fetch, a take buffering) shows the equalizer: four bars out of phase that ease down to rest instead of freezing.

## Motion language
Principle: motion confirms, it never performs. Nothing jumps at the user: content fades and rises a few pixels (6% of its height), sizes ease, and only the three signature moments are allowed to be expressive.

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
| [Owner pick: fashion e-commerce (Pinterest)](https://www.pinterest.com/pin/924082417309102222/) | Off-white canvas, white hairline cards, one orange used only on the main action and the selected state; near-black secondary CTA; pill chips and a pill search with a round filter key. |
| [Owner pick: clothing shop app (Pinterest)](https://www.pinterest.com/pin/893964594794357650/) | Big soft radii, round header icon buttons, generous whitespace and calm sentence-case headings with "See all". (Its gradients and shadows are not taken.) |
| [Monochrome player "Unsayable / Charcoal" (Pinterest search: music player app ui)](https://www.pinterest.com/search/pins/?q=music%20player%20app%20ui) | Two equal action pills (dark Play, grey Shuffle); numbered rows with "Artist · 4:21" meta; colour-free UI that lets artwork carry. |
| [Dark player "Low Life" (Pinterest search: minimal dark music app ui)](https://www.pinterest.com/search/pins/?q=minimal%20dark%20music%20app%20ui) | Neutral graphite surfaces where the single orange element is the play/pause key and the progress line. |
| [Artist page "Astrid S" (same search)](https://www.pinterest.com/search/pins/?q=minimal%20dark%20music%20app%20ui) | Small uppercase kicker over a bold title, a single muted stats line, clear section heads. |
| [Apple Music Sing lyrics (Pinterest search: karaoke lyrics app screen)](https://www.pinterest.com/search/pins/?q=karaoke%20lyrics%20app%20screen) | Large left-aligned lyric lines; the active line is the only bright thing, past and future recede. |

No images, logos or layouts were copied; only principles.

## Assumptions
- Android first (APK). Flutter, Riverpod, go_router.
- Lyrics from LRCLIB (free, open, no key) when online; manual .lrc import otherwise.
- Social backend: Supabase (auth, Postgres with row-level security for private/public, storage). Runs offline-first without it.
