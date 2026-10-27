# Reference breakdown: what `breakdown.md` holds

Written in Stage 2 from `bin/analyze.sh` output plus your own reading of the contact sheets and full-res frames. It is working evidence, not a deliverable: keep it tight. Measured values are labelled measured; everything else is an estimate or a hypothesis and says so.

1. **Source & coverage**: file/link, segment and offset, which methods ran (probe, cut detection, sheets, transcript), and which layers are missing (no audio, no transcript, user-supplied words).
2. **Specs**: duration, dimensions, FPS, audio present; confirmed cuts (times + count) vs candidates with their threshold; distinct setups; words per minute only with a complete dialogue record, stating the denominator.
3. **Transcript / dialogue summary**: time, speaker, words, slang and delivery, from `transcript.srt` checked against the audio; uncertain words marked `[?]`. For third-party footage keep quotes short and use a timestamped summary.
4. **Shot-by-shot**: `| Source time | Framing | Camera move | On screen / props | Action & delivery |`, one row per confirmed shot, with gestures, expressions, product contact and timing.
5. **People & setups**: hair, makeup, wardrobe, jewelry, nails, gestures per setup; what changes between the hook and the main take.
6. **Setting & image**: objects and positions, surfaces, lighting direction and quality, grade, visible camera traits (phone wobble, lens, exposure).
7. **Text & overlays**: timestamped captions, handles, watermarks, emoji, UI. Separate added overlays (to exclude) from physical label text (to preserve).
8. **Audio**: music character and ducking, effects, mic quality, room tone, other voices. Loudness from `loudness.txt`. Never invent a track name.
9. **Retention mechanisms**: hook, open loops, pattern interrupts, show-while-telling, payoffs, framed as hypotheses.
10. **Measurements & disagreements**: where the cut detector, the sheets and the transcript disagreed, and how each was resolved.
11. **Handoff**: the transferable structure, what must be replaced, which products and packshots are needed, the hard shots, continuity needs.

Reconciliation rules: cut timing = detector + frame confirmation; camera, wardrobe and props = consecutive frames; words = transcript + listening where it matters; label and screen text = full-res frames only, never guessed.
