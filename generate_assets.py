"""
Makazi Estate — Asset Generator
Generates:
  1. App icon (all launcher sizes + 512 play store version)
  2. Web PWA icons (192, 512 regular + maskable)
  3. Feature graphic 1024x500
  4. Favicon (32x32)
"""

from PIL import Image, ImageDraw, ImageFont
import math, os, sys

# ── Brand colours ──────────────────────────────────────────────────────────────
BLUE_DARK   = (21,  101, 192)   # #1565C0  deep blue
BLUE_MID    = (33,  150, 243)   # #2196F3  brand blue
BLUE_LIGHT  = (100, 181, 246)   # #64B5F6
ORANGE      = (255, 152,   0)   # #FF9800  brand accent
ORANGE_DARK = (245, 124,   0)   # #F57C00
GREEN_PALM  = ( 56, 142,  60)   # #388E3C  palm leaves
GREEN_LIGHT = (102, 187, 106)   # #66BB6A
TRUNK       = (121,  85,  72)   # #795548  coconut trunk
WHITE       = (255, 255, 255)
CREAM       = (255, 248, 225)   # warm white


# ── Helpers ───────────────────────────────────────────────────────────────────

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i]-c1[i])*t) for i in range(3))

def gradient_rect(draw, x0, y0, x1, y1, c_top, c_bottom):
    for y in range(y0, y1):
        t = (y - y0) / max(y1 - y0, 1)
        c = lerp_color(c_top, c_bottom, t)
        draw.line([(x0, y), (x1, y)], fill=c)


# ── Core icon painter ─────────────────────────────────────────────────────────

def draw_icon(size):
    """Draw the Makazi Estate icon at any square size."""
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s    = size

    # --- Rounded-square gradient background ---
    r = int(s * 0.18)           # corner radius
    # draw gradient onto a temp surface then paste with rounded mask
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bg_d = ImageDraw.Draw(bg)
    gradient_rect(bg_d, 0, 0, s, s, BLUE_DARK, BLUE_MID)

    # rounded-rect mask
    mask = Image.new("L", (s, s), 0)
    md   = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, s-1, s-1], radius=r, fill=255)
    img.paste(bg, (0, 0), mask)
    draw = ImageDraw.Draw(img)

    # ── Coconut Palm Tree (right side) ─────────────────────────────────────
    # trunk base and top position
    tx   = int(s * 0.67)
    ty_b = int(s * 0.82)   # trunk bottom
    ty_t = int(s * 0.28)   # trunk top (lean left slightly)
    tw   = max(int(s * 0.035), 2)

    # trunk as a slightly curved trapezoid
    trunk_pts = [
        (tx - tw,       ty_b),
        (tx + tw,       ty_b),
        (tx + tw//2,    ty_t),
        (tx - tw//2,    ty_t),
    ]
    draw.polygon(trunk_pts, fill=TRUNK)

    # palm leaves — 7 fronds radiating from trunk top
    cx, cy = tx - int(s*0.01), ty_t  # crown centre
    leaf_len = int(s * 0.23)
    angles = [-110, -75, -45, -10, 20, 50, 80]
    for angle in angles:
        rad = math.radians(angle)
        ex = cx + int(leaf_len * math.cos(rad))
        ey = cy + int(leaf_len * math.sin(rad))
        # thick leaf
        lw = max(int(s * 0.025), 2)
        mid_x = cx + int(leaf_len * 0.5 * math.cos(rad))
        mid_y = cy + int(leaf_len * 0.5 * math.sin(rad))
        col = GREEN_LIGHT if angle < 0 else GREEN_PALM
        draw.line([(cx, cy), (mid_x, mid_y)], fill=GREEN_LIGHT, width=lw)
        draw.line([(mid_x, mid_y), (ex, ey)], fill=col, width=max(lw-1,1))

    # coconuts (3 small circles near crown)
    coc_r = max(int(s * 0.03), 2)
    for dx, dy in [(-2, 6), (5, 8), (-7, 5)]:
        draw.ellipse([
            cx + int(dx*s/100) - coc_r,
            cy + int(dy*s/100) - coc_r,
            cx + int(dx*s/100) + coc_r,
            cy + int(dy*s/100) + coc_r,
        ], fill=ORANGE_DARK)

    # ── House (left-centre) ────────────────────────────────────────────────
    hw   = int(s * 0.40)   # house body width
    hh   = int(s * 0.26)   # house body height
    hx   = int(s * 0.13)   # left edge of house
    hy_b = int(s * 0.82)   # bottom of house
    hy_t = hy_b - hh       # top of house body

    # house body
    draw.rectangle([hx, hy_t, hx+hw, hy_b], fill=WHITE)

    # roof (triangle)
    roof_overhang = int(s * 0.04)
    roof_peak_x   = hx + hw//2
    roof_peak_y   = hy_t - int(s * 0.20)
    roof_pts = [
        (hx - roof_overhang,      hy_t),
        (hx + hw + roof_overhang, hy_t),
        (roof_peak_x,             roof_peak_y),
    ]
    draw.polygon(roof_pts, fill=ORANGE)

    # door (centred)
    dw = int(hw * 0.22)
    dh = int(hh * 0.50)
    dx = hx + (hw - dw)//2
    dy = hy_b - dh
    draw.rectangle([dx, dy, dx+dw, hy_b], fill=BLUE_DARK)
    # door knob
    knob_r = max(int(s*0.012), 1)
    draw.ellipse([dx+dw-knob_r*2, dy+dh//2-knob_r,
                  dx+dw,          dy+dh//2+knob_r], fill=ORANGE)

    # left window
    wx, wy = hx + int(hw*0.07), hy_t + int(hh*0.18)
    ww, wh = int(hw*0.20), int(hh*0.30)
    draw.rectangle([wx, wy, wx+ww, wy+wh], fill=BLUE_LIGHT)
    draw.line([(wx+ww//2, wy), (wx+ww//2, wy+wh)], fill=WHITE, width=max(int(s*0.005),1))
    draw.line([(wx, wy+wh//2), (wx+ww, wy+wh//2)], fill=WHITE, width=max(int(s*0.005),1))

    # right window
    wx2 = hx + hw - int(hw*0.07) - ww
    draw.rectangle([wx2, wy, wx2+ww, wy+wh], fill=BLUE_LIGHT)
    draw.line([(wx2+ww//2, wy), (wx2+ww//2, wy+wh)], fill=WHITE, width=max(int(s*0.005),1))
    draw.line([(wx2, wy+wh//2), (wx2+ww, wy+wh//2)], fill=WHITE, width=max(int(s*0.005),1))

    # ── Ground line ────────────────────────────────────────────────────────
    draw.rectangle([int(s*0.04), hy_b, int(s*0.96), hy_b + max(int(s*0.02),2)],
                   fill=GREEN_PALM)

    return img


# ── Feature Graphic painter ───────────────────────────────────────────────────

def draw_feature_graphic():
    W, H = 1024, 500
    img  = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)

    # gradient background  dark-blue → mid-blue
    gradient_rect(draw, 0, 0, W, H, (13, 71, 161), (21, 101, 192))   # #0D47A1 → #1565C0

    # decorative circles (subtle)
    for cx2, cy2, cr2, alpha in [(820, 80, 220, 25), (950, 420, 150, 18), (100, 380, 180, 18)]:
        circ = Image.new("RGBA", (W, H), (0,0,0,0))
        cd   = ImageDraw.Draw(circ)
        cd.ellipse([cx2-cr2, cy2-cr2, cx2+cr2, cy2+cr2], fill=(255,255,255,alpha))
        img.paste(circ, (0,0), circ)
        draw = ImageDraw.Draw(img)   # redraw handle after paste

    # paste scaled icon (left side)
    icon = draw_icon(320)
    icon_rgb = Image.new("RGB", icon.size, (21, 101, 192))
    icon_rgb.paste(icon, (0, 0), icon)
    paste_y = (H - 320) // 2
    img.paste(icon_rgb, (60, paste_y))

    # ── Text ──────────────────────────────────────────────────────────────
    try:
        # try Windows system fonts
        font_bold  = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf",  72)
        font_reg   = ImageFont.truetype("C:/Windows/Fonts/arial.ttf",    32)
        font_small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf",    24)
    except Exception:
        font_bold  = ImageFont.load_default()
        font_reg   = font_bold
        font_small = font_bold

    tx = 440   # text start x

    # App name
    draw.text((tx, 120), "Makazi Estate", fill=WHITE, font=font_bold)

    # Tagline
    draw.text((tx, 210), "Find Your Dream Property in Tanzania", fill=CREAM, font=font_reg)

    # Orange divider
    draw.rectangle([tx, 260, tx+380, 265], fill=ORANGE)

    # Feature bullets
    features = [
        "🏠  Buy, Sell & Rent Properties",
        "📍  Location-Based Search",
        "💬  In-App Messaging",
        "🔔  Instant Notifications",
    ]
    fy = 280
    try:
        font_feat = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 22)
    except Exception:
        font_feat = font_small
    for feat in features:
        draw.text((tx, fy), feat, fill=CREAM, font=font_feat)
        fy += 36

    # Bottom badge
    badge_y = H - 60
    draw.rounded_rectangle([tx, badge_y-18, tx+230, badge_y+18], radius=18, fill=ORANGE)
    try:
        font_badge = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 20)
    except Exception:
        font_badge = font_small
    draw.text((tx+18, badge_y-10), "Available on Play Store", fill=WHITE, font=font_badge)

    return img


# ── Output paths ──────────────────────────────────────────────────────────────

BASE = r"C:\Users\collins\Documents\real_estate flutter\real_estate_app"

LAUNCHER_SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

def save_png(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(f"  OK  {path.replace(BASE, '').lstrip(chr(92))}")


def main():
    print("\n=== Generating Makazi Estate Assets ===\n")

    # ── 1. Android launcher icons ─────────────────────────────────────────
    print("Android launcher icons:")
    for folder, size in LAUNCHER_SIZES.items():
        icon = draw_icon(size).convert("RGBA")
        dest = os.path.join(BASE, "android", "app", "src", "main", "res", folder, "ic_launcher.png")
        save_png(icon, dest)
        # round icon (same image — Android uses the whole canvas rounded)
        dest_r = os.path.join(BASE, "android", "app", "src", "main", "res", folder, "ic_launcher_round.png")
        save_png(icon, dest_r)

    # ── 2. Play Store hi-res icon (512×512) ───────────────────────────────
    print("\nPlay Store hi-res icon (512×512):")
    icon_512 = draw_icon(512).convert("RGBA")
    save_png(icon_512, os.path.join(BASE, "assets", "store", "icon_512.png"))
    save_png(icon_512, os.path.join(BASE, "playstore_assets", "icon_512.png"))

    # ── 3. Web / PWA icons ────────────────────────────────────────────────
    print("\nPWA icons:")
    for sz in [192, 512]:
        ic = draw_icon(sz).convert("RGBA")
        save_png(ic, os.path.join(BASE, "web", "icons", f"Icon-{sz}.png"))
        save_png(ic, os.path.join(BASE, "web", "icons", f"Icon-maskable-{sz}.png"))

    # favicon (32×32 with white BG)
    fav = draw_icon(32).convert("RGBA")
    fav_bg = Image.new("RGBA", (32,32), WHITE)
    fav_bg.paste(fav, (0,0), fav)
    save_png(fav_bg.convert("RGB"), os.path.join(BASE, "web", "favicon.png"))

    # ── 4. Feature Graphic (1024×500) ─────────────────────────────────────
    print("\nPlay Store feature graphic:")
    fg = draw_feature_graphic()
    save_png(fg, os.path.join(BASE, "playstore_assets", "feature_graphic_1024x500.png"))

    print("\n=== All assets generated successfully! ===\n")


if __name__ == "__main__":
    main()
