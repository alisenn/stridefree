"""Google Play mağaza görsellerini üretir (store/play/).

- icon-512.png          : 512x512 uygulama simgesi
- feature-graphic.png   : 1024x500 tanıtım görseli
- screenshots/*.png     : iOS ekran görüntülerinden 9:16 (1080x1920) telefon görselleri

Kullanım: python store/tools/play_assets.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "store" / "play"
ICON = ROOT / "assets" / "icon" / "icon-1024.png"
SHOTS = ROOT / "store" / "screenshots" / "tr"

BG = (18, 22, 14)
ACCENT = (182, 243, 92)
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_REG = "C:/Windows/Fonts/segoeui.ttf"


def icon():
    Image.open(ICON).convert("RGB").resize((512, 512), Image.LANCZOS).save(
        OUT / "icon-512.png"
    )


def feature_graphic():
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), BG)
    # Yumuşak yeşil parıltı
    glow = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(glow)
    d.ellipse((-150, -120, 520, 620), fill=(40, 58, 22))
    img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(120)), 1.0)

    ic = Image.open(ICON).convert("RGB").resize((300, 300), Image.LANCZOS)
    mask = Image.new("L", ic.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 299, 299), radius=66, fill=255)
    img.paste(ic, (70, 100), mask)

    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(FONT_BOLD, 78)
    sub = ImageFont.truetype(FONT_REG, 34)
    tag = ImageFont.truetype(FONT_BOLD, 24)
    d.text((420, 140), "StrideFree", font=title, fill=(240, 244, 232))
    d.text((424, 245), "Koşu bandınızı telefondan", font=sub, fill=(200, 208, 190))
    d.text((424, 290), "yönetin — tamamen ücretsiz", font=sub, fill=(200, 208, 190))
    pill = "ABONELİK YOK · REKLAM YOK"
    tw = d.textlength(pill, font=tag)
    d.rounded_rectangle((424, 355, 424 + tw + 36, 355 + 46), radius=23, fill=(46, 66, 24))
    d.text((442, 362), pill, font=tag, fill=ACCENT)
    img.save(OUT / "feature-graphic.png")


def screenshots():
    dst = OUT / "screenshots"
    dst.mkdir(parents=True, exist_ok=True)
    for src in sorted(SHOTS.glob("*.png")):
        im = Image.open(src).convert("RGB")
        # iOS durum çubuğunu / çentiği kes (Android mağazasında iPhone arayüzü görünmesin)
        im = im.crop((0, 175, im.width, im.height))
        # Play telefon ekran görüntüleri tam 9:16 olmalı
        tw, th = 1080, 1920
        scale = th / im.height
        nw = round(im.width * scale)
        im = im.resize((nw, th), Image.LANCZOS)
        # Yan boşlukları kenar sütunlarını uzatarak doldur (alt bar vb. kesintisiz görünsün)
        x0 = (tw - nw) // 2
        canvas = Image.new("RGB", (tw, th))
        canvas.paste(im.crop((0, 0, 1, th)).resize((x0, th)), (0, 0))
        canvas.paste(
            im.crop((nw - 1, 0, nw, th)).resize((tw - x0 - nw, th)), (x0 + nw, 0)
        )
        canvas.paste(im, (x0, 0))
        canvas.save(dst / src.name)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    icon()
    feature_graphic()
    screenshots()
    for p in sorted(OUT.rglob("*.png")):
        print(p.relative_to(ROOT), Image.open(p).size)
