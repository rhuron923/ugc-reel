# Brand profile template

The onboarding interview fills this in and saves it as `<library>/brand.md`. It is the complete and only source of brand truth for every run: the skill never browses the web or reads the brand's site. If a script needs a fact that is not here, the skill asks in one line and, with permission, adds the answer here.

Copy everything below the line, fill it from the interview answers, delete the guidance in parentheses.

---

# Brand profile: <Brand name>

Saved <YYYY-MM-DD>. Edit by hand any time, or tell the skill "update the brand profile".

## Products in scope

(One row per product that can appear in a reel. Spoken name = what a creator would call it in a caption. Label text = the words printed on the pack, for prompts and QC only. Physical description = shape, colour, cap/closure, materials, print, in enough words that a video model can reproduce it. Scale anchor = the product's size against a familiar object: "about the height of a phone standing on end", "fits in one palm", "a thumb-width shorter than the X". Packshot = a public URL of a front-on packshot on a plain background, or `file: packshots/<name>` if it must be staged with the upload helper.)

| Spoken name | Label text (as printed) | Size | Physical description | Scale anchor | Packshot |
|---|---|---|---|---|---|
| | | | | | |

Hero product (the one most reels lead with): <name>
Relations between packs when two share a frame: (e.g. "the shampoo stands a thumb-width shorter than the tube")

## Product texture line

(Only if the product is ever shown leaving its pack. One exact phrase, repeated word for word in every prompt that shows it, because video models drift on texture: e.g. "an off-white, glossy, conditioner-like fluid that slumps and spreads". Write "none" if the product is never shown out of the pack.)

## Label-out rule

(Which faces of the pack may ever be seen. Default: "the printed front faces the camera throughout; when it is turned it pivots a little to one side and back, and the printed front is the only face ever seen." Add exceptions here if the back or sides are fine.)

## Talking points, in priority order

1. (The single most important thing the product does, in one plain sentence.)
2. …

## Claims the creator MAY make

- (Exact phrasings that are cleared, e.g. "helps keep colour bright". Ingredients by name if allowed. Usage directions in plain words.)

## Claims the creator must NOT make

- (Percentages, stats, studies, "clinically proven", medical claims, competitor names, prices, discounts, media mentions, invented credentials. Add the brand's own red lines.)

## Words banned in captions

(Brand-speak that would read as a listing: e.g. formula, technology, nourishing, ideal for, suitable for, all types, fl oz, "1. step". The skill's generic list applies too.)

## First-person testimonial policy

(`flag` = lines where the AI creator claims personal use or results are marked ⚑ in the preview and need approval, with an unflagged alternative offered; `allow` = no flag; `never` = rewrite them out. Default `flag`: an AI avatar is not a real customer.)

## Voice notes

(Anything about how the brand's creators sound. Who is she, what does she already know, what would she never say. Two or three lines.)

## Concept playbooks

(Optional. Files in `playbooks/` with ad concepts that have worked for this brand or its peers, one line each on what they hold. The skill reads them before writing captions; this profile wins any conflict.)

## Defaults

- aspect: 9:16
- resolution: 720p
- feed format: 1100x1080 (approved test variants are reformatted to this in Stage 6)
- caption font: Montserrat (falls back to Arial Bold)
- caption_humanizer: off   (on = every caption set and variant goes through references/caption-humanizer.md before it is shown)
- product-name caption: <exact text to burn under the pack at the product moment, e.g. the spoken name in title case>

## File staging

(`none` | `s3` | `cmd`, mirrored in ~/.config/ugc-reel/config.env. `none` means packshots must have public URLs and beat repairs that need an uploaded still are off.)
