#!/usr/bin/env python3
"""
ZenRide App Icon Generator — v2
Theme: Open road, forest horizon, dawn sun. No rider — you are the rider.
Design principles (per iOS HIG + app icon UX research):
  - Single focal point: vanishing-point road leading to the sun
  - 3-color palette: amber sky / forest green / charcoal road
  - Bold silhouette shapes that survive scaling to 60px
  - High contrast between all regions
Outputs: 1024×1024 PNG
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUTPUT_PATH = os.path.join(
    os.path.dirname(__file__),
    "../Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
)

# ── Horizon sits at 50% — equal sky and ground, strong bisection ──────────────
HORIZON_Y = int(SIZE * 0.50)

# ── Color palette (3 families) ────────────────────────────────────────────────
SKY_TOP    = (210,  80,  20)   # deep burnt-orange at top
SKY_MID    = (240, 140,  40)   # warm amber
SKY_HRZ    = (255, 200,  90)   # bright gold near horizon

GRD_TOP    = ( 38,  80,  38)   # forest green near horizon
GRD_BOT    = ( 18,  42,  18)   # deep forest at bottom

ROAD_COLOR = ( 32,  32,  32)   # near-black charcoal
ROAD_EDGE  = ( 55,  52,  42)   # shoulder warm tint
DASH_COLOR = (240, 185,  80)   # golden amber dashes

TREE_COLOR = ( 12,  35,  12)   # very dark forest silhouette

SUN_CORE   = (255, 245, 180)   # near-white warm core
SUN_MID    = (255, 210,  80)   # gold halo
SUN_OUTER  = (250, 160,  40)   # amber outer glow


def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


# ── Sky ───────────────────────────────────────────────────────────────────────

def draw_sky(img):
    draw = ImageDraw.Draw(img)
    for y in range(HORIZON_Y):
        t = y / HORIZON_Y
        if t < 0.55:
            color = lerp_color(SKY_TOP, SKY_MID, t / 0.55)
        else:
            color = lerp_color(SKY_MID, SKY_HRZ, (t - 0.55) / 0.45)
        draw.line([(0, y), (SIZE, y)], fill=color)


# ── Ground ────────────────────────────────────────────────────────────────────

def draw_ground(img):
    draw = ImageDraw.Draw(img)
    ground_h = SIZE - HORIZON_Y
    for y in range(ground_h):
        t = y / ground_h
        color = lerp_color(GRD_TOP, GRD_BOT, t ** 0.7)
        draw.line([(0, HORIZON_Y + y), (SIZE, HORIZON_Y + y)], fill=color)


# ── Sun ───────────────────────────────────────────────────────────────────────

def draw_sun(img):
    """Bold sun disc centered at the vanishing point, sitting on the horizon."""
    vp_x = SIZE // 2
    vp_y = HORIZON_Y

    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)

    # Soft outer glow bloom (drawn first, widest)
    bloom_layers = [
        (340, 200, (*SUN_OUTER, 18)),
        (240, 150, (*SUN_OUTER, 35)),
        (170, 110, (*SUN_MID,   60)),
        (120,  80, (*SUN_MID,   90)),
    ]
    for rx, ry, color in bloom_layers:
        gd.ellipse([vp_x - rx, vp_y - ry, vp_x + rx, vp_y + ry], fill=color)

    blurred_glow = glow.filter(ImageFilter.GaussianBlur(radius=28))
    img.paste(blurred_glow, (0, 0), blurred_glow)

    # Crisp sun disc — circle centered on horizon (half visible above, half behind treeline)
    draw = ImageDraw.Draw(img)
    sun_r = 82
    # Full circle disc
    draw.ellipse(
        [vp_x - sun_r, vp_y - sun_r, vp_x + sun_r, vp_y + sun_r],
        fill=SUN_MID
    )
    # Bright core
    core_r = 52
    draw.ellipse(
        [vp_x - core_r, vp_y - core_r, vp_x + core_r, vp_y + core_r],
        fill=SUN_CORE
    )


# ── Forest treeline silhouette ─────────────────────────────────────────────────

def draw_treeline(img):
    """
    Two solid dark silhouette masses, one on each side, with a jagged pine-tip
    profile. Drawn as single filled polygons — reads perfectly at 60px.
    Trees are tallest at outer edges, shortest near the road opening.
    """
    draw = ImageDraw.Draw(img)

    def pine_profile(cx, base_y, height, width):
        """Returns the top-point of one pine triangle for profiling."""
        return (cx, base_y - height), (cx - width, base_y), (cx + width, base_y)

    # ── Left treeline ─────────────────────────────────────────────────────────
    # Profile: start at left edge high, create jagged pine peaks, end at road edge
    # Road left edge at horizon: vp_x - road_horizon_half_w
    road_hw_horizon = 22
    vp_x = SIZE // 2
    road_left_at_hz = vp_x - road_hw_horizon  # ~490

    # Pine peak positions (x, peak_y) from left edge inward
    # Heights drop as we approach the center road gap
    left_peaks = [
        (  0,  HORIZON_Y - 310),   # left edge — very tall, partially clipped
        ( 55,  HORIZON_Y - 265),
        (115,  HORIZON_Y - 295),
        (175,  HORIZON_Y - 240),
        (235,  HORIZON_Y - 270),
        (295,  HORIZON_Y - 215),
        (355,  HORIZON_Y - 245),
        (405,  HORIZON_Y - 180),
        (445,  HORIZON_Y - 160),
        (470,  HORIZON_Y - 120),
        (490,  HORIZON_Y -  75),   # near road edge, short
    ]

    # Build left polygon: trace the jagged top, then rectangle base
    # Start: (0, SIZE) — bottom-left corner
    left_poly = [(0, SIZE), (0, HORIZON_Y)]
    for (px, py) in left_peaks:
        left_poly.append((px, py))
    # Close down to road edge at horizon, then fill down
    left_poly.append((road_left_at_hz, HORIZON_Y))
    left_poly.append((road_left_at_hz, SIZE))
    draw.polygon(left_poly, fill=TREE_COLOR)

    # ── Right treeline (mirror) ────────────────────────────────────────────────
    right_peaks = [
        (SIZE,       HORIZON_Y - 310),
        (SIZE - 55,  HORIZON_Y - 265),
        (SIZE - 115, HORIZON_Y - 295),
        (SIZE - 175, HORIZON_Y - 240),
        (SIZE - 235, HORIZON_Y - 270),
        (SIZE - 295, HORIZON_Y - 215),
        (SIZE - 355, HORIZON_Y - 245),
        (SIZE - 405, HORIZON_Y - 180),
        (SIZE - 445, HORIZON_Y - 160),
        (SIZE - 470, HORIZON_Y - 120),
        (SIZE - 490, HORIZON_Y -  75),
    ]
    road_right_at_hz = vp_x + road_hw_horizon

    right_poly = [(SIZE, SIZE), (SIZE, HORIZON_Y)]
    for (px, py) in right_peaks:
        right_poly.append((px, py))
    right_poly.append((road_right_at_hz, HORIZON_Y))
    right_poly.append((road_right_at_hz, SIZE))
    draw.polygon(right_poly, fill=TREE_COLOR)


# ── Road ──────────────────────────────────────────────────────────────────────

def draw_road(img):
    """
    Perspective trapezoid road. Wide at bottom, narrow at vanishing point.
    Strong dark charcoal — high contrast against forest green.
    """
    draw = ImageDraw.Draw(img)
    vp_x = SIZE // 2
    bottom_y = SIZE

    road_bottom_hw = 295   # half-width at very bottom edge
    road_horizon_hw = 22   # half-width at horizon (matches treeline gap)

    road_pts = [
        (vp_x - road_horizon_hw, HORIZON_Y),
        (vp_x + road_horizon_hw, HORIZON_Y),
        (vp_x + road_bottom_hw,  bottom_y),
        (vp_x - road_bottom_hw,  bottom_y),
    ]
    draw.polygon(road_pts, fill=ROAD_COLOR)

    # Warm shoulder strips (subtle, just a few px)
    shoulder_w = 22
    left_sh = [
        (vp_x - road_horizon_hw,                  HORIZON_Y),
        (vp_x - road_horizon_hw + 4,               HORIZON_Y),
        (vp_x - road_bottom_hw  + shoulder_w,      bottom_y),
        (vp_x - road_bottom_hw,                    bottom_y),
    ]
    right_sh = [
        (vp_x + road_horizon_hw - 4,               HORIZON_Y),
        (vp_x + road_horizon_hw,                   HORIZON_Y),
        (vp_x + road_bottom_hw,                    bottom_y),
        (vp_x + road_bottom_hw  - shoulder_w,      bottom_y),
    ]
    draw.polygon(left_sh,  fill=ROAD_EDGE)
    draw.polygon(right_sh, fill=ROAD_EDGE)


# ── Center dashes ─────────────────────────────────────────────────────────────

def draw_dashes(img):
    """
    Perspective dashed center line. Fewer dashes, more spacing — cleaner.
    Converge toward the sun at vanishing point.
    """
    draw = ImageDraw.Draw(img)
    vp_x = SIZE // 2
    bottom_y = SIZE

    road_bottom_hw = 295
    road_horizon_hw = 22

    num_dashes = 7
    dash_fraction = 0.38   # each dash is 38% of its slot

    for i in range(num_dashes):
        t0 = (i + 0.1) / num_dashes
        t1 = (i + 0.1 + dash_fraction) / num_dashes
        if t1 > 1.0:
            break

        y0 = HORIZON_Y + int((bottom_y - HORIZON_Y) * t0)
        y1 = HORIZON_Y + int((bottom_y - HORIZON_Y) * t1)

        def hw_at(y):
            t = (y - HORIZON_Y) / (bottom_y - HORIZON_Y)
            return road_horizon_hw + (road_bottom_hw - road_horizon_hw) * t

        # Dash is 5% of road width at that depth
        dw0 = hw_at(y0) * 0.050
        dw1 = hw_at(y1) * 0.050

        pts = [
            (vp_x - dw0, y0), (vp_x + dw0, y0),
            (vp_x + dw1, y1), (vp_x - dw1, y1),
        ]
        draw.polygon(pts, fill=DASH_COLOR)


# ── Vignette ──────────────────────────────────────────────────────────────────

def draw_vignette(img):
    """Gentle dark vignette at edges to keep the eye centered on the road/sun."""
    vig = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vig)

    steps = 20
    for i in range(steps):
        t = i / steps
        alpha = int(95 * (t ** 2.2))
        rx = int(SIZE * (0.5 - 0.48 * (1 - t)))
        ry = int(SIZE * (0.5 - 0.48 * (1 - t)))
        vd.ellipse(
            [SIZE // 2 - rx, SIZE // 2 - ry,
             SIZE // 2 + rx, SIZE // 2 + ry],
            outline=(0, 0, 0, alpha),
            width=int(SIZE * 0.028)
        )

    vig_blur = vig.filter(ImageFilter.GaussianBlur(radius=36))
    img.paste(vig_blur, (0, 0), vig_blur)


# ── iOS rounded corners ───────────────────────────────────────────────────────

def apply_rounded_corners(img, radius_fraction=0.2236):
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
    print("ZenRide Icon Generator v2 — Open Road")
    print(f"Output: {os.path.abspath(OUTPUT_PATH)}")

    img = Image.new("RGBA", (SIZE, SIZE), (*GRD_BOT, 255))

    print("  Sky gradient...")
    draw_sky(img)

    print("  Ground gradient...")
    draw_ground(img)

    print("  Sun glow + disc...")
    draw_sun(img)

    print("  Forest treeline silhouette...")
    draw_treeline(img)

    print("  Road...")
    draw_road(img)

    print("  Center dashes...")
    draw_dashes(img)

    print("  Vignette...")
    draw_vignette(img)

    print("  Rounded corners...")
    img = apply_rounded_corners(img)

    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(img, (0, 0), img)

    os.makedirs(os.path.dirname(os.path.abspath(OUTPUT_PATH)), exist_ok=True)
    final.save(OUTPUT_PATH, "PNG", optimize=False)
    print(f"  Done. {SIZE}×{SIZE} PNG written.")
    print(f'\n  open "{os.path.abspath(OUTPUT_PATH)}"')


if __name__ == "__main__":
    main()
