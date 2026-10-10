"""Generate the Unsung launcher icons (legacy + adaptive) from the brand font.

Usage: python3 tool/make_icons.py   (writes into android/app/src/main/res)
The mark: a heavy, narrow "U" in paper white on the stage colour over a
cue-orange underline, the blank line you sing into.
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

STAGE = (15, 13, 12, 255)
INK = (244, 238, 230, 255)
CUE = (255, 91, 36, 255)

# The launch splash is white (the app runs on the light theme), so it gets
# its own mark in dark ink with the light theme's cue.
SPLASH_STAGE = "#F6F5F3"
SPLASH_INK = (20, 20, 21, 255)
SPLASH_CUE = (194, 65, 12, 255)
FONT = "assets/fonts/BricolageGrotesque.ttf"
RES = pathlib.Path("android/app/src/main/res")


def mark(size, with_bg=True, scale=1.0, ink=INK, cue=CUE):
    img = Image.new("RGBA", (size, size), STAGE if with_bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, int(size * 0.62 * scale))
    try:
        font.set_variation_by_axes([96, 800, 75])  # opsz, wght, wdth
    except Exception:
        pass
    box = d.textbbox((0, 0), "U", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (size - w) / 2 - box[0]
    stripe_h = size * 0.075 * scale
    gap = size * 0.045 * scale
    y = (size - (h + gap + stripe_h)) / 2 - box[1]
    d.text((x, y), "U", font=font, fill=ink)
    # The blank line you sing into: a cue underline as wide as the glyph.
    top = y + box[3] + gap
    d.rectangle([x + box[0], top, x + box[2], top + stripe_h], fill=cue)
    return img


def rounded(img):
    s = img.size[0]
    m = Image.new("L", (s, s), 0)
    ImageDraw.Draw(m).ellipse([0, 0, s - 1, s - 1], fill=255)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(img, (0, 0), m)
    return out


densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, f in densities.items():
    d = RES / f"mipmap-{name}"
    d.mkdir(parents=True, exist_ok=True)
    s = int(48 * f)
    sq = mark(s * 4).resize((s, s), Image.LANCZOS)
    sq.save(d / "ic_launcher.png")
    rounded(mark(s * 4)).resize((s, s), Image.LANCZOS).save(d / "ic_launcher_round.png")
    # Adaptive foreground: 108dp canvas, art kept inside the 66dp safe zone.
    fg = int(108 * f)
    mark(fg * 4, with_bg=False, scale=0.62).resize((fg, fg), Image.LANCZOS).save(d / "ic_launcher_foreground.png")
    mark(fg * 4, with_bg=False, scale=0.62, ink=SPLASH_INK, cue=SPLASH_CUE).resize(
        (fg, fg), Image.LANCZOS
    ).save(d / "splash_foreground.png")

any_dpi = RES / "mipmap-anydpi-v26"
any_dpi.mkdir(parents=True, exist_ok=True)
xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
(any_dpi / "ic_launcher.xml").write_text(xml)
(any_dpi / "ic_launcher_round.xml").write_text(xml)
values = RES / "values"
values.mkdir(parents=True, exist_ok=True)
(values / "ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#0F0D0C</color>\n</resources>\n'
)
(values / "splash_background.xml").write_text(
    f'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="splash_background">{SPLASH_STAGE}</color>\n</resources>\n'
)
mark(1024).save("docs/icon-1024.png")
print("icons written")
