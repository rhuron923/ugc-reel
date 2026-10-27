#!/usr/bin/env python3
"""make-ass.py — build a burn-in caption file (.ass) from a small JSON spec.

    python3 make-ass.py captions.json > caps-v1.ass

captions.json:
{
  "font": "Montserrat",          # optional; Arial if absent (make-ass does not check what is installed)
  "size": 60,                    # optional; 56 / 60 / 64 are the house sizes (vary per export, see SKILL.md fingerprint)
  "top_margin": 180,             # optional; 170 / 180 / 195
  "bottom_margin": 320,          # optional
  "captions": [
    {"start": 0.30, "end": 2.60, "pos": "top", "text": "this is how i get ready\\nfor a swim"},
    {"start": 4.80, "end": 7.60, "pos": "bottom", "text": "Product Name", "box": false}
  ]
}

pos: "top" (default) or "bottom" (product-name line under the pack). "\\n" in text is a manual line break.
box: true draws an opaque dark box behind the line (used to cover stray burned-in text in a take).
Canvas is 720x1280 (9:16). For other aspects pass "play_res": [w, h].
"""
import json, sys

def ts(t):
    h = int(t // 3600); m = int((t % 3600) // 60); s = t % 60
    return f"{h}:{m:02d}:{s:05.2f}"

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    # UTF-8 in and out with LF line endings: Windows Python otherwise reads and writes cp1252 with CRLF.
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    font = spec.get("font", "Arial")
    size = int(spec.get("size", 60))
    top = int(spec.get("top_margin", 180))
    bottom = int(spec.get("bottom_margin", 320))
    w, h = spec.get("play_res", [720, 1280])
    caps = spec.get("captions") or sys.exit("make-ass.py: no captions")
    out = [
        "[Script Info]", "ScriptType: v4.00+", f"PlayResX: {w}", f"PlayResY: {h}", "WrapStyle: 0",
        "ScaledBorderAndShadow: yes", "",
        "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, "
        "Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
        f"Style: Top,{font},{size},&H00FFFFFF,&H00FFFFFF,&H00301A14,&H90000000,-1,0,0,0,100,100,0,0,1,6,3,8,44,44,{top},1",
        f"Style: Bottom,{font},{size},&H00FFFFFF,&H00FFFFFF,&H00301A14,&H90000000,-1,0,0,0,100,100,0,0,1,6,3,2,44,44,{bottom},1",
        f"Style: TopBox,{font},{size},&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,3,14,0,8,44,44,{top},1",
        f"Style: BottomBox,{font},{size},&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,3,14,0,2,44,44,{bottom},1",
        "", "[Events]",
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
    ]
    for c in caps:
        style = "Bottom" if c.get("pos") == "bottom" else "Top"
        if c.get("box"):
            style += "Box"
        text = str(c["text"]).replace("\\n", "\\N").replace("\n", "\\N")
        out.append(f"Dialogue: 0,{ts(float(c['start']))},{ts(float(c['end']))},{style},,0,0,0,,{text}")
    print("\n".join(out))

if __name__ == "__main__":
    main()
