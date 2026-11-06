# Meta Ads Manager playbook (Grace Coffee)

How Grace Coffee ads get into Meta Ads Manager, the settings every ad must have, and what was learned building the November 2026 E-Book ads. Written 2026-11-06 so the work can be picked up on another computer. Claude's local memory notes from these sessions are copied in the last section, since that memory doesn't travel between machines.

## Account

| | |
|---|---|
| Ad account | `act=1247526180638204` |
| Business | `289313642460749` |
| E-Book Ads ad set | `120251488769440546` |
| Browser | Claude in Chrome (the user's real Chrome). The in-app browser pane triggered a 90-minute "new device" security block on Meta. |

Ad editor URL for one ad (swap `<AD_ID>`):

```
https://adsmanager.facebook.com/adsmanager/manage/ads/edit/standalone?act=1247526180638204&business_id=289313642460749&selected_ad_ids=<AD_ID>&selected_adset_ids=120251488769440546&treenav=true&current_step=0
```

## Settings every ad must have

Ryan corrected the first 7 E-Book ads by hand on 2026-11-05 and asked for these on every ad from then on:

1. **Personalized destinations: all off.** Optimize website destination, Shop, Product browsing, Browser add-ons.
2. **Related media: removed.** Meta adds one automatically; delete it so it reads 0 selected.
3. **Format display options: Single media only.** Remove every other format.
4. **Right column / Search results: the full, uncropped 4:5 image**, not Meta's 1.91:1 crop.
5. **Creative setup: every option off.** Branding, Website highlights, Site links, Products.

Also standard:
- Upload images **inside the ad editor** (Add media → Upload), never through the Ad Account Media library (see "Error #2446386" below).
- The 4:5 (or 1:1 / 3:4) is the main image. The 9:16 goes to Stories, Reels and other vertical placements.
- Meta AI "Crop and expand" off. Auto-translation off.
- CTA: See details. Headline: "Get your FREE e-book".
- No offer in the creative (the free bag is a back-end surprise since 2026-10-29).
- Nothing gets published by Claude. Ryan reviews and publishes.

Open items Ryan raised on 2026-11-06 and is handling himself:
- **"Add video effects"** (Essential enhancement) gets turned on by Meta for video ads. It was on for the Be Still Dark Ocean video ad (`120251492144470546`). Ryan is turning it off.
- **"Optimize text per person: Enabled"** shows on the duplicated ads. It isn't in the Creative setup list, so the copies probably inherited it from the source ad. Decide whether it should be off as a standard.
- In a multi-ad selection, Related media showed "Mixed media." All 24 new ads were checked at 0 related media, so if it appears, look for an ad outside that set.

## E-book links and copy

All links are `https://grace-coffee.myklpages.com/l/<code>`.

| E-book | Link code | Primary text |
|---|---|---|
| Be Still (anxiety) | `XESGbi` | Racing thoughts at 2 a.m. are more common than you’d think, and feeling anxious doesn’t make anyone a bad Christian. This free 7-day guided prayer journey is a gentle way to bring those worries to God. |
| Lets Reset / Take A Break Right Here (7-Day Reset) | `XESGbi` | Same as Be Still. |
| Praying For Him (husbands) | `SNVjMj` | Want to pray for your husband but don’t know where to start? This free 7-day guide covers one area of his life each day, with a written prayer you can add his name to. |
| Two Become One (newlyweds) | `RWM6wW` | Just married and not sure how to start praying together? This free 7-day guide gives you a short verse and a prayer to read out loud as a couple each day. |
| Refresh (busy moms) | `VP35rw` | Mama, running on empty? This free 7-day prayer reset takes about 10 minutes a day, and it’s fine if there’s a little one on your lap while you do it. |
| Little Hearts (kids under 5) | `WbE7gG` | Got a toddler or preschooler at home? This free 7-day prayer challenge takes about five minutes a day, so you can pray over your little one at nap time or bedtime. |

## Where things stand (2026-11-06)

Campaign folder: `UGC Library/campaigns/20261105 - Grace Coffee Ads/` (in Ryan's OneDrive, not in this repo). Upload-ready files with short names are in its `Upload/` folder.

- **E-Book Ads, first 7** (Lets Reset, Take A Break Right Here, Little Hearts, Two Become One, Be Still, Praying For Him, Refresh): built by hand from `E-Book Ads build checklist.md`, then corrected by Ryan. "In Need of a Reset" was already live.
- **More Prayer Guides, 24 ads**: built in the E-Book Ads ad set, unpublished, for Ryan to review and publish. All 24 passed a final check: name, URL, copy, Creative setup 0, Related media 0, Single media only, Personalized destinations off, media "1 selected with 2 aspect ratios", no #2446386 errors.
  - Be Still: cappuccino, cover, desk mug, marble hands, plus the Dark Ocean video (4:5 video, 9:16 vertical, translation off).
  - Praying For Him: bedsheets, couch book, cover, glasses mug, iced coffee.
  - Two Become One: couple table, cover, holding hands, living room, wedding rings.
  - Refresh: cover, craft table, iced coffee, kitchen, mom kids.
  - Little Hearts: baking, cover, playroom, sandbox.
  - Creator on all of them: Lauren. Ad names come from the naming sheet and match the file names in `20261105 - Grace Coffee - More Prayer Guides/`.
  - The first ad built by hand is `120251492071450546`. The other 23 were duplicated from it.
- **Not started**: `20261106 - Grace Coffee - Videos/` (9 raw .MOV files) and the Wallpaper Pack videos sheet that still needs video IDs.

## How the 24 ads were built

Building one ad correctly by hand and duplicating it was much faster than the wizard for each ad, and the duplicates keep all five standard settings.

1. Build one ad completely by hand and check all five settings.
2. Duplicate it N-1 times in the same ad set (Ads Manager → Duplicate, keep in the same ad set).
3. For each copy, change only: ad name, media, website URL, primary text.
   - **Media:** Media → Change selections → Upload, picking the 4:5 and 9:16 together. When they pair, it reads "1 selected with 2 aspect ratios included". If it shows "2 selected", keep only the 4:5, then Customize media → Vertical → Upload your own → the 9:16.
   - **URL:** set it *after* clicking Done in the creative wizard. Set before, it sometimes reverted to the source ad's URL and turned Branding back on (Creative setup 1/x). Re-check URL and Creative setup after saving.
   - **Video ads:** translation defaults on (13 languages plus voice dubbing). In the Translation step, untick every language until it reads "0 languages selected"; voice then turns off. Check "Add video effects".
4. Re-open every ad at the end and check name, URL, copy and the five settings.

Mechanics when Claude drives Chrome:
- The Upload button opens a native file picker Claude can't see. Patch `HTMLInputElement.prototype.click` in the page so the file input stays in the DOM, then hand the file to Chrome's file-upload tool. That tool has a 10 MB per-call limit, so upload videos one at a time and save the upload sub-dialog before adding the next.
- Meta renders the editor lazily: scroll down before looking for "Change selections" and similar buttons.
- If the window freezes or minimizes, restore it and open a new tab. If a page sticks on loading, navigate to the editor URL again.

### The Media section looks different on these ads

The 24 new ads show "Uploaded media, 1 selected with 2 aspect ratios included" with a "Not optimized" badge. Ryan's corrected ads show one row per placement group (Feeds / Stories, Reels / Right column) with an Edit menu.

- The per-row layout appears once any placement has its own file, such as the uncropped 4:5 swapped into Right column.
- The paired layout means Meta decides placement itself: the 9:16 goes to vertical placements and the 4:5 everywhere else. Per-placement settings are behind **Customize media**.
- "Not optimized" is Meta's suggestion to add 1:1 and 1.91:1 versions. It doesn't block publishing.
- The Right column version can't be seen from the Media section in the paired layout. Check it under Customize media. If it's cropped, uploading the 4:5 into that slot switches the ad to the per-row layout.

## Bulk import (`bin/meta-upload.sh`)

The README's "Meta bulk upload" section explains the sheet builder. What happened when it was used on 2026-11-05:

- **Error #2446386 "The image you selected is not available"** hit every ad whose images were uploaded through the Business Suite / Ad Account Media library that day, imported and hand-built alike. A hand-built ad looked clean at first and was flagged on Meta's re-check a minute later. New hashes, layouts and manual builds didn't fix it. Ryan found the cause: library uploads fail, uploads made inside the ad editor work.
- Image hashes are not the file's MD5. Read them from Business Suite → Media Library → Ad Account Media → click the image → "Hash". Meta hashes pixels, so re-saving a PNG keeps the hash and re-encoding to JPG changes it.
- Each image hash can be used only once per ad ("Duplicate of ad asset values are not allowed", #1815629).
- These ads use Automatic Format, so an image with no placement label is dropped and the ad imports with no media.
- Products stays forced on in this Advantage+ campaign in the import; turn it off in the editor.
- **Lesson:** when an imported ad errors, first build one ad by hand with the same image and wait a minute for Meta's re-check before changing the file. Hours went into iterating the upload file before that test.

Given the above, building by hand (or duplicating one finished ad) with in-editor uploads is the reliable path for images until the library issue is understood.

## Claude's memory notes (copied from the original computer)

- **Meta ad setup standards:** the five settings above, plus in-editor uploads, 9:16 for Stories/Reels, AI crop off, translation off.
- **Meta bulk upload lessons:** the bulk-import section above.
- **No offer in ads:** since 2026-10-29, no free-bag badge, banner or offer copy in any new creative; the free bag stays on the landing page. Static headline/footer font is Canva's "Choco Chip".
- **Never delete in Canva:** never delete designs, assets or folders in Canva, even Claude's own drafts. List leftovers and Ryan deletes them.
- **Lengthening footage:** repeat the opening segment whole (one loop point). A small hitch is fine. No seam-matched multi-loops.
- **This repo:** private `rhuron923/ugc-reel`, cloned to `~/.claude/skills/ugc-reel`. The OneDrive project folder holds a copy of the skill files but is not a git repo. Never commit `UGC Library/`, `Raw Videos/` or `references/Reference Ads/`.

To restore these on a new computer, ask Claude to read this file and save the notes above to its memory.
