#!/usr/bin/env python3
"""
ZenRide App Icon Generator — v3
"The road of the year."

Design intelligence applied (iOS HIG + 2025 icon research):
  ∙ Distinctive burnt-amber dawn sky — unowned color territory in navigation
  ∙ Cinematic dark-to-gold gradient: near-black burgundy → rich amber → bright gold
  ∙ Sharp individual pine silhouettes — bold triangles, readable at 60px
  ∙ Sun framed by treeline gap: trees occlude outer halo, bright core shines through
  ∙ Horizontal horizon glow — luminous dawn ray sweeping the treeline
  ∙ Road center reflection — sun glinting on dark asphalt
  ∙ Subtle film grain — premium, AI-native texture signal
  ∙ No rider — the road IS the metaphor. You are already on it.
  ∙ No baked shadows — iOS 26 Liquid Glass compatible
  ∙ Single focal point: road → horizon → sun

Outputs: 1024×1024 PNG
"""

import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUTPUT_PATH = os.path.join(
    os.path.dirname(__file__),
    "../Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
)

# Horizon sits at 47% — slightly above center, gives road a grander presence
HORIZON_Y = int(SIZE * 0.47)

# ── Color palette ─────────────────────────────────────────────────────────────
# Sky: near-black burgundy-amber at top → rich burnt amber → bright gold horizon
SKY_TOP    = ( 22,   4,   0)   # near-black dark burgundy
SKY_Q1     = ( 80,  18,   2)   # deep dark red-amber
SKY_MID    = (170,  55,   8)   # rich burnt orange
SKY_Q3     = (225, 110,  15)   # warm amber
SKY_HRZ    = (255, 185,  50)   # bright gold at horizon

# Ground: very dark forest, near-black at bottom
GRD_HRZ    = ( 22,  48,  18)   # dark forest at horizon
GRD_MID    = ( 14,  32,  12)   # deeper forest
GRD_BOT    = (  8,  18,   6)   # near-black forest at bottom

# Road
ROAD_DARK  = ( 18,  18,  18)   # near-black asphalt
ROAD_EDGE  = ( 42,  38,  28)   # warm shoulder strip

# Dashes
DASH_COLOR = (220, 160,  45)   # golden amber

# Trees
TREE_COLOR = (  8,  22,   6)   # ultra-dark forest silhouette

# Sun
SUN_CORE   = (255, 252, 220)   # near-white warm core
SUN_RING   = (255, 215,  70)   # gold ring
SUN_AURA   = (245, 155,  30)   # amber aura

# Horizon light
HRZ_GLOW   = (255, 220,  90)   # bright gold horizon sweep

random.seed(42)   # reproducible grain


def lerp(a, b, t):
    t = max(0.0, min(1.0, t))
    return a + (b - a) * t


def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


# ── Sky ───────────────────────────────────────────────────────────────────────

def draw_sky(img):
    """
    4-stop gradient: near-black burgundy → deep amber → bright gold.
    Darker sky = more cinematic, more contrast against the lit horizon.
    """
    draw = ImageDraw.Draw(img)
    stops = [
        (0.00, SKY_TOP),
        (0.30, SKY_Q1),
        (0.60, SKY_MID),
        (0.82, SKY_Q3),
        (1.00, SKY_HRZ),
    ]
    for y in range(HORIZON_Y):
        t = y / HORIZON_Y
        # Find which segment we're in
        color = stops[0][1]
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                seg_t = (t - t0) / (t1 - t0)
                color = lerp_color(c0, c1, seg_t)
                break
        draw.line([(0, y), (SIZE, y)], fill=color)


# ── Ground ────────────────────────────────────────────────────────────────────

def draw_ground(img):
    draw = ImageDraw.Draw(img)
    ground_h = SIZE - HORIZON_Y
    for y in range(ground_h):
        t = y / ground_h
        if t < 0.35:
            color = lerp_color(GRD_HRZ, GRD_MID, t / 0.35)
        else:
            color = lerp_color(GRD_MID, GRD_BOT, (t - 0.35) / 0.65)
        draw.line([(0, HORIZON_Y + y), (SIZE, HORIZON_Y + y)], fill=color)


# ── Horizon glow ──────────────────────────────────────────────────────────────

def draw_horizon_glow(img):
    """
    A thin luminous band at the exact horizon — the precise moment of sunrise.
    Sweeps across the full width. This is behind the treeline.
    """
    band_h = 80
    band = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)

    for i in range(band_h):
        t = i / band_h
        # Bell curve: fade in and out vertically
        alpha = int(180 * math.sin(math.pi * t) ** 1.4)
        y = HORIZON_Y - band_h // 2 + i
        bd.line([(0, y), (SIZE, y)], fill=(*HRZ_GLOW, alpha))

    blurred = band.filter(ImageFilter.GaussianBlur(radius=12))
    img.paste(blurred, (0, 0), blurred)


# ── Sun ───────────────────────────────────────────────────────────────────────

def draw_sun(img):
    """
    Bold sun disc at the vanishing point. Center ON the horizon line.
    Disc radius extends beyond the road gap — treeline will frame the outer halo.
    Road leads straight to the bright core. Compositional payoff.
    """
    vp_x = SIZE // 2
    vp_y = HORIZON_Y

    # ── Soft aura (drawn first, behind everything) ────────────────────────
    aura = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ad = ImageDraw.Draw(aura)

    aura_layers = [
        (480, 260, (*SUN_AURA,  10)),
        (360, 200, (*SUN_AURA,  20)),
        (260, 148, (*SUN_AURA,  38)),
        (185, 108, (*SUN_RING,  55)),
        (130,  78, (*SUN_RING,  80)),
    ]
    for rx, ry, color in aura_layers:
        ad.ellipse([vp_x - rx, vp_y - ry, vp_x + rx, vp_y + ry], fill=color)

    aura_blur = aura.filter(ImageFilter.GaussianBlur(radius=32))
    img.paste(aura_blur, (0, 0), aura_blur)

    # ── Crisp disc ────────────────────────────────────────────────────────
    draw = ImageDraw.Draw(img)
    sun_r = 78

    # Outer ring
    draw.ellipse(
        [vp_x - sun_r, vp_y - sun_r, vp_x + sun_r, vp_y + sun_r],
        fill=SUN_RING
    )
    # Mid ring
    draw.ellipse(
        [vp_x - int(sun_r * 0.74), vp_y - int(sun_r * 0.74),
         vp_x + int(sun_r * 0.74), vp_y + int(sun_r * 0.74)],
        fill=lerp_color(SUN_RING, SUN_CORE, 0.5)
    )
    # Core
    core_r = int(sun_r * 0.50)
    draw.ellipse(
        [vp_x - core_r, vp_y - core_r, vp_x + core_r, vp_y + core_r],
        fill=SUN_CORE
    )


# ── Pine treeline ─────────────────────────────────────────────────────────────

def draw_treeline(img):
    """
    Individual sharp triangular pines — a serrated silhouette that reads at 60px.
    Trees are tallest at the outer edges, shortest near the road gap.
    The sun's outer glow is partially behind the trees; its bright core shines
    through the gap — the road leads to it.
    """
    draw = ImageDraw.Draw(img)

    road_horizon_hw = 22
    vp_x = SIZE // 2
    road_left  = vp_x - road_horizon_hw   # ≈ 490
    road_right = vp_x + road_horizon_hw   # ≈ 534

    def build_treeline(pines, left_x, right_x, side="left"):
        """
        Build a filled polygon for one side's treeline.
        pines: list of (center_x, height, half_base_width) from outer edge inward.
        Returns polygon points list.
        """
        poly = []
        if side == "left":
            poly.append((left_x, SIZE))
            poly.append((left_x, HORIZON_Y))
        else:
            poly.append((right_x, SIZE))
            poly.append((right_x, HORIZON_Y))

        for (cx, h, bw) in pines:
            poly.append((cx - bw, HORIZON_Y + 8))   # valley slightly below horizon
            poly.append((cx, HORIZON_Y - h))          # pine tip
            poly.append((cx + bw, HORIZON_Y + 8))    # valley

        if side == "left":
            poly.append((road_left, HORIZON_Y))
            poly.append((road_left, SIZE))
        else:
            poly.append((road_right, HORIZON_Y))
            poly.append((road_right, SIZE))

        return poly

    # Left pines — from x=0 inward. (cx, height, half_base_width)
    # Sharp triangular: bw ≈ height × 0.30 (classic pine proportions)
    left_pines = [
        ( 22, 195, 52),   # partially clipped at left edge
        ( 82, 218, 56),   # tallest visible
        (152, 200, 52),
        (225, 188, 50),
        (300, 172, 46),
        (368, 155, 42),
        (425, 130, 35),
        (464, 100, 26),
        (485,  62, 18),   # small inner tree, right at road shoulder
    ]

    # Right pines — mirror from x=SIZE inward
    right_pines = [
        (SIZE - 22,  195, 52),
        (SIZE - 82,  218, 56),
        (SIZE - 152, 200, 52),
        (SIZE - 225, 188, 50),
        (SIZE - 300, 172, 46),
        (SIZE - 368, 155, 42),
        (SIZE - 425, 130, 35),
        (SIZE - 464, 100, 26),
        (SIZE - 485,  62, 18),
    ]

    left_poly  = build_treeline(left_pines,  0,    road_left,  "left")
    right_poly = build_treeline(right_pines, road_right, SIZE, "right")

    draw.polygon(left_poly,  fill=TREE_COLOR)
    draw.polygon(right_poly, fill=TREE_COLOR)


# ── Road ──────────────────────────────────────────────────────────────────────

def draw_road(img):
    """
    Perspective trapezoid — wide at bottom, converging to vanishing point.
    Near-black asphalt, warm shoulder edges.
    """
    draw = ImageDraw.Draw(img)
    vp_x = SIZE // 2
    bottom_y = SIZE
    road_bot_hw  = 308
    road_hrz_hw  = 22

    # Main asphalt
    draw.polygon([
        (vp_x - road_hrz_hw, HORIZON_Y),
        (vp_x + road_hrz_hw, HORIZON_Y),
        (vp_x + road_bot_hw,  bottom_y),
        (vp_x - road_bot_hw,  bottom_y),
    ], fill=ROAD_DARK)

    # Warm shoulder strips
    sh = 20
    draw.polygon([
        (vp_x - road_hrz_hw,      HORIZON_Y),
        (vp_x - road_hrz_hw + 4,  HORIZON_Y),
        (vp_x - road_bot_hw + sh, bottom_y),
        (vp_x - road_bot_hw,      bottom_y),
    ], fill=ROAD_EDGE)
    draw.polygon([
        (vp_x + road_hrz_hw - 4,  HORIZON_Y),
        (vp_x + road_hrz_hw,      HORIZON_Y),
        (vp_x + road_bot_hw,      bottom_y),
        (vp_x + road_bot_hw - sh, bottom_y),
    ], fill=ROAD_EDGE)


# ── Road center reflection ─────────────────────────────────────────────────────

def draw_road_reflection(img):
    """
    Narrow golden reflection in the center of the road — sun glinting on asphalt.
    Fades out from the horizon downward. Premium depth cue.
    """
    vp_x   = SIZE // 2
    bottom_y = SIZE
    road_bot_hw  = 308
    road_hrz_hw  = 22

    ref_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ref_img)

    # Reflection fades out over top 38% of road length
    fade_end_y = HORIZON_Y + int((bottom_y - HORIZON_Y) * 0.42)
    steps = fade_end_y - HORIZON_Y

    for i in range(steps):
        y = HORIZON_Y + i
        t = i / steps
        alpha = int(72 * (1 - t) ** 1.6)

        # Width of the reflection strip scales with road width
        road_t = i / (bottom_y - HORIZON_Y)
        hw = road_hrz_hw + (road_bot_hw - road_hrz_hw) * road_t
        rw = hw * 0.12   # reflection is 12% of road width

        rd.line([(vp_x - rw, y), (vp_x + rw, y)],
                fill=(*SUN_RING, alpha))

    blurred = ref_img.filter(ImageFilter.GaussianBlur(radius=6))
    img.paste(blurred, (0, 0), blurred)


# ── Center dashes ─────────────────────────────────────────────────────────────

def draw_dashes(img):
    """6 golden amber dashes in perspective — each one a trapezoid."""
    draw = ImageDraw.Draw(img)
    vp_x = SIZE // 2
    bottom_y = SIZE
    road_bot_hw = 308
    road_hrz_hw = 22

    n = 6
    dash_len = 0.40   # each dash takes 40% of its slot

    for i in range(n):
        t0 = (i + 0.15) / n
        t1 = t0 + dash_len / n

        y0 = HORIZON_Y + int((bottom_y - HORIZON_Y) * t0)
        y1 = HORIZON_Y + int((bottom_y - HORIZON_Y) * t1)

        def road_hw(y):
            rt = (y - HORIZON_Y) / (bottom_y - HORIZON_Y)
            return road_hrz_hw + (road_bot_hw - road_hrz_hw) * rt

        dw0 = road_hw(y0) * 0.053
        dw1 = road_hw(y1) * 0.053

        draw.polygon([
            (vp_x - dw0, y0), (vp_x + dw0, y0),
            (vp_x + dw1, y1), (vp_x - dw1, y1),
        ], fill=DASH_COLOR)


# ── Film grain ────────────────────────────────────────────────────────────────

def apply_grain(img, strength=9):
    """
    Subtle film grain over the sky. Premium signal — used by top AI and
    design apps (Perplexity, Midjourney, high-end photo apps) to add tactility.
    Pure Python implementation: per-scanline noise, sky only.
    """
    img_data = img.load()
    for y in range(HORIZON_Y):
        # Grain fades out near horizon (less grain where horizon is bright)
        t = y / HORIZON_Y
        row_strength = int(strength * (0.4 + 0.6 * (1 - t) ** 0.6))
        for x in range(SIZE):
            r, g, b = img_data[x, y][:3]
            n = random.randint(-row_strength, row_strength)
            img_data[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
                255
            )


# ── Vignette ──────────────────────────────────────────────────────────────────

def draw_vignette(img):
    """Dark corner vignette — focuses the eye to the center road/sun."""
    vig = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)

    steps = 22
    for i in range(steps):
        t = i / steps
        alpha = int(100 * (t ** 2.0))
        rx = int(SIZE * (0.50 - 0.47 * (1 - t)))
        ry = int(SIZE * (0.50 - 0.47 * (1 - t)))
        vd.ellipse(
            [SIZE // 2 - rx, SIZE // 2 - ry,
             SIZE // 2 + rx, SIZE // 2 + ry],
            outline=(0, 0, 0, alpha),
            width=int(SIZE * 0.030)
        )

    vig_blur = vig.filter(ImageFilter.GaussianBlur(radius=40))
    img.paste(vig_blur, (0, 0), vig_blur)


# ── Rounded corners ───────────────────────────────────────────────────────────

def apply_rounded_corners(img, radius_fraction=0.2236):
    """iOS squircle approximation."""
    radius = int(SIZE * radius_fraction)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255
    )
    mask = mask.filter(ImageFilter.GaussianBlur(radius=1))
    result = img.copy().convert("RGBA")
    result.putalpha(mask)
    return result


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("ZenRide Icon Generator v3 — The Open Road")
    print(f"Output: {os.path.abspath(OUTPUT_PATH)}")

    img = Image.new("RGBA", (SIZE, SIZE), (*GRD_BOT, 255))

    print("  [1/9] Sky gradient (cinematic burnt amber)...")
    draw_sky(img)

    print("  [2/9] Ground gradient (deep forest)...")
    draw_ground(img)

    print("  [3/9] Horizon glow (dawn light beam)...")
    draw_horizon_glow(img)

    print("  [4/9] Sun aura + disc...")
    draw_sun(img)

    print("  [5/9] Pine treeline silhouettes...")
    draw_treeline(img)

    print("  [6/9] Road...")
    draw_road(img)

    print("  [7/9] Road center reflection...")
    draw_road_reflection(img)

    print("  [8/9] Center dashes...")
    draw_dashes(img)

    print("  Film grain (premium texture)...")
    apply_grain(img, strength=9)

    print("  Vignette...")
    draw_vignette(img)

    print("  [9/9] iOS rounded corners...")
    img = apply_rounded_corners(img)

    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(img, (0, 0), img)

    os.makedirs(os.path.dirname(os.path.abspath(OUTPUT_PATH)), exist_ok=True)
    final.save(OUTPUT_PATH, "PNG", optimize=False)
    print(f"\n  Done. {SIZE}×{SIZE} PNG written.")
    print(f'  open "{os.path.abspath(OUTPUT_PATH)}"')


if __name__ == "__main__":
    main()
