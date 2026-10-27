# Ad naming (Stage 6)

Every cut approved for testing is saved under its **ad name**, built exactly the way the brand's naming sheet builds it, so the file, the Meta ad and the Motion report all carry the same string. The sheet is linked in `brand.md` → Ad naming, together with this brand's fixed field values. Review cuts before approval keep the `YYYYMMDD - Hook vX` working names (SKILL.md → File naming); ad names exist only for what will run.

## How the sheet builds a name

The **Creative Name Generator** tab computes, per row:

```
=B & " - " & TEXTJOIN(" - ", TRUE, E:AH)
```

so the name is the Creative File Name, then every **non-empty** field from Creator onward, in column order, joined with " - ". Concept Name (C) and Test/Batch # (D) are recorded but never appear in the name. Build the name the same way and skip empty fields; never add a field the sheet does not have.

| Generator col | Field | Glossary col | Prefix |
|---|---|---|---|
| B | Creative File Name (freeform) | — | none |
| C | Concept Name (freeform, not in name) | — | — |
| D | Test/Batch # (freeform, not in name) | — | — |
| E | Creator | C | none (a name) |
| F | Creative Format | D | `f-` |
| G | Video Format | E | `as-` |
| H | Messaging | F | `m-` |
| I | Content Genre | G | `cg-` |
| J | Hook/Headline | H | `h-` |
| K | Ad Focus | I | `p-` |
| L | Talent/Influencer | J | `i-` |
| M | Talent/Influencer Gender | K | `gen-` |
| N | Talent Age | L | `age-` |
| O | Asset Length | M | `len-` |
| P | Offer | N | `o-` |
| Q | Landing Page Type | O | `lp-` |
| R | Audio | P | `a-` |
| S | Asset Size | Q | `sz-` |
| T–Y | Specific Test Parameters (spare) | R–W | as the glossary says |

Glossary values start on row 7 under the headers in row 6. **Read the glossary fresh at every Stage 6**: values get added between runs. The generator's dropdowns are strict, so a value that is not in its glossary column cannot be used in a row. A new value goes into the glossary first.

## Filling the fields

- **Fixed per brand**: whatever `brand.md` → Ad naming fixes (creator, format, offer, talent for AI footage). Use them as written.
- **Creative File Name**: the hook label in lowercase plus version and variant letter, `<label> v<X><letter>`, e.g. `coffee drinker types v3a`, `kitchen pour over v1c`. Every approved variant gets a letter, the lead one included (`a`).
- **Concept Name**: the hook label as in the working files. **Test/Batch #**: the campaign folder name.
- **Hook/Headline**: `h-` + the hook in a few lowercase words, true to the hook caption (2–7 words; shorten a long static POV line to its core). Reuse an existing glossary hook when the variant's hook is that hook; otherwise it is a new value.
- **Video Format, Messaging, Content Genre, Ad Focus**: pick the closest existing glossary value for what the cut actually does. Propose a new value only when nothing fits, and say why.
- **Asset Length**: the smallest `len-` bucket at or above the measured duration (13.0 s → `len-15sec`, 9.5 s → `len-10sec`).
- **Audio**: `a-none` for a silent master; for Route D footage that kept its track, the glossary value that describes it.
- **Asset Size**: `sz-9x16` for the vertical cut, `sz-1100x1080` for the feed cut. The two are **separate ads** and differ only in this field.
- **Landing Page Type**: never guessed. Ask once per campaign with the glossary's `lp-` values listed; blank is allowed and drops the field.
- Talent, gender, age for real people in Route D footage come from who is on screen (ask if unsure); AI-generated talent uses the brand's AI values.

## The file name

The file is the ad name plus `.mp4`, made filesystem-safe: drop `? * " < > |`, turn `/ \ :` into `-`, collapse double spaces. The exact ad name (with any `?` or `/`) stays in the sheet and in `Approved for testing/ad names.csv` (`file,ad name`, one line per file). Long names are fine on this machine (Windows long paths are on; a 427-character path was tested). If a path write ever fails for length, say so and stop; never shorten an ad name on your own.

## Logging to the sheet

Only with a Google Sheets connector in the session; without one, write `ad names.csv` and give the user the rows to paste.

1. Show one table before anything is written: each file, its full ad name, and the new glossary values it needs (column and value). This is the user's one confirmation for the names and the sheet write together. Edits to tags are applied and the table is shown again.
2. On OK, append each new value to the first empty cell of its glossary column (rows 7+).
3. Append one generator row per file in the first rows whose column B is empty, writing **B:S only** (and T–Y if used). Never write column AI: it holds the formula.
4. Read back column AI for those rows and compare each with the name you built. A mismatch is reported and the files are left named by the sheet's version.
5. Never edit or delete existing rows or glossary values.
