# Changelog

## 0.3.2 – clean and premium

- Neutral graphite palette (dark) and a cleaner off-white (light); the cue orange is the only colour on screen.
- Calmer type: less condensed titles, sentence-case buttons, chips, tabs and section titles in Bricolage; mono kept for metadata.
- Pills: search field, outlined filter chips (ink when selected), equal-size buttons. The Sing key in the tab bar is a round cue disc.
- Song sheet: Sing and Rehearse side by side, one lit; quieter secondary actions; larger artwork corners.
- Takes and Stage cards: more padding, hairline border, one quiet meta line instead of boxed tags.
- Starter shelf: no fade gradient, clean thumbnail over text, "Start with a classic" section title.
- Empty states use a neutral icon disc instead of a cue icon.

## 0.3.1 – quiet surfaces

- Colour is an accent only. The drifting ambient light is gone; the backdrop is the neutral stage colour with a fine static film grain. Light theme moves to a cleaner off-white.
- No glows or shadows anywhere: Sing and record buttons, Spotlight transition (now a clean circular reveal), pitch ribbon, Unsinging ribbon, splash, onboarding, sign-in.
- Tab bar docked to the bottom edge (frosted, hairline top) instead of floating; the active tab gets a short cue underline.
- Cards are plain surfaces with a hairline; no sheen, no tint on your own posts.

## 0.3.0 – glass

- Liquid-glass system: ambient stage light behind the app, glass surfaces with a specular rim and sheen, frosted sheets with a lit edge, glassy inputs.
- Floating glass tab bar with a lens that glides under the selected tab.
- Stage post cards on glass (your own carry a faint cue tint).
- Loading: a shared shimmer sweep on skeletons; an equalizer for music-related waits (library scan, lyrics, link fetch, buffering).
- Launch sequence: the U mark's underline becomes a waveform, the word opens on the variable width axis, the voice lifts away, the line settles under "Unsung" and the stage light rises into the app. Native splash matches its first frame on every Android version.
- "Start with a classic": a shelf of 12 well-known songs (official YouTube uploads). Tapping one opens From a link pre-filled; nothing is downloaded until you bring it in.

## 0.2.0 – songs from links, review fixes

- **From a link:** paste a YouTube / YouTube Music link or Share → Unsung from the YouTube app. Audio comes through the Studio server (yt-dlp, Deno, optional PO-token provider) or on the phone (youtube_explode_dart). Imported songs join the library with their cover, work with Quick/Studio unsinging, and can be deleted from the song sheet.
- Song sheet redesigned: Sing leads, Rehearse second, secondary actions as real buttons; the finished instrumental settles to tape grey.
- Studio lyrics are never blank: skeleton while loading, retry / add lyrics when they can't be fetched.
- Breathing lyrics no longer reflow mid-line; one gradient layer per frame; the clock stops while paused. Past lyrics are 24/600 for contrast.
- Spotlight uses the brief's 600ms emphasized curve with a pill-to-disc hero morph. Tabs cross-fade.
- Branded confirm sheets replace stock dialogs. Profile stats survive large text. READY moves to the row's meta line. Feed cards get a hairline; load-more is a skeleton.
- All motion, size and blur values are tokens.
- Tests: link parsing and flow, Studio session and Rehearse state machines (with fake players), server link endpoints, 2x text on profile and post card. New screenshots: link sheet (both themes), song sheet in its glass sheet, the Stage screen, Library without access, lyrics offline, Unsinging painter frames.

## 0.1.1 – polish

- Library: alphabet scrub rail on long libraries (24+ songs) with a letter bubble and haptics; songs always sorted by title.
- Sheets are frosted glass, as the design brief asks for transient layers.
- Private ↔ public is now one switch: the lock flips into a broadcast mark with a cue ripple when a take goes public (share sheet and post owner panel).
- Button labels use a bolder, larger mono style so primary actions read at a glance.

## 0.1.0 – first build

- Design system: warm stage palette with one cue accent, Bricolage Grotesque + JetBrains Mono variable fonts, motion tokens, light and dark.
- Onboarding with illustrated beats.
- Library from the device with search, cover art and Ready filter; permission flow.
- On-device vocal removal (Quick) with the Unsinging animation; optional Studio separation server (Demucs).
- Rehearse: vocal guide fader, key change, synced lyrics (LRCLIB or pasted), timing nudge.
- Studio: count-in, recording, breathing lyrics, live pitch ribbon, sync estimate.
- Takes: non-destructive mix (voice, music, reverb, echo, sync), stats.
- The Stage: email-code sign-in, profiles, feed (For you / Following), in-place playback, likes, comments, follows, private-first sharing, reporting.
