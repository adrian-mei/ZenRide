#!/usr/bin/env python3
"""
ZenRide App Icon Generator
Theme: Lone rider, open road, forest horizon — dawn light, deep green, total zen.
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


def lerp_color(c1, c2, t):
    """Linear interpolate between two RGB tuples."""
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def draw_sky_gradient(img):
    """Top 55% — warm amber dawn sky gradient."""
    draw = ImageDraw.Draw(img)
    sky_bottom_y = int(SIZE * 0.55)

    # Amber at very top → warm peach → misty sage at horizon
    top_color = (245, 166, 35)       # #F5A623 warm amber
    mid_color = (232, 200, 140)      # #E8C88C warm peach
    horizon_color = (180, 205, 175)  # misty sage-green

    for y in range(sky_bottom_y):
        t = y / sky_bottom_y
        if t < 0.5:
            color = lerp_color(top_color, mid_color, t * 2)
        else:
            color = lerp_color(mid_color, horizon_color, (t - 0.5) * 2)
        draw.line([(0, y), (SIZE, y)], fill=color)


def draw_ground_gradient(img):
    """Bottom 45% — forest green ground."""
    draw = ImageDraw.Draw(img)
    horizon_y = int(SIZE * 0.55)

    forest_top = (107, 158, 107)   # #6B9E6B mist-edge
    forest_mid = (45, 90, 45)      # #2D5A2D mid forest
    forest_bot = (26, 61, 26)      # #1A3D1A deep forest

    ground_height = SIZE - horizon_y
    for y in range(ground_height):
        t = y / ground_height
        if t < 0.4:
            color = lerp_color(forest_top, forest_mid, t / 0.4)
        else:
            color = lerp_color(forest_mid, forest_bot, (t - 0.4) / 0.6)
        draw.line([(0, horizon_y + y), (SIZE, horizon_y + y)], fill=color)


def draw_mist_band(img):
    """Soft mist at the horizon blending sky into forest."""
    horizon_y = int(SIZE * 0.55)
    mist_height = int(SIZE * 0.08)
    mist_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mist_img)

    mist_color = (200, 220, 195)  # pale sage-white

    for i in range(mist_height):
        # Bell-curve alpha: peak in middle of band
        t = i / mist_height
        alpha = int(120 * math.sin(math.pi * t))
        draw.line(
            [(0, horizon_y - mist_height // 2 + i),
             (SIZE, horizon_y - mist_height // 2 + i)],
            fill=(*mist_color, alpha)
        )

    mist_blurred = mist_img.filter(ImageFilter.GaussianBlur(radius=8))
    img.paste(mist_blurred, (0, 0), mist_blurred)


def draw_sun_glow(img):
    """Warm radial glow at the vanishing point (horizon center)."""
    vp_x = SIZE // 2
    vp_y = int(SIZE * 0.55)

    glow_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow_img)

    # Multiple concentric ellipses, fading out
    layers = [
        (60, 35, (255, 220, 100, 160)),   # hot core
        (120, 70, (255, 200, 80, 100)),
        (220, 120, (245, 180, 60, 60)),
        (360, 180, (240, 160, 40, 30)),
        (520, 240, (220, 140, 30, 12)),
    ]
    for rx, ry, color in layers:
        draw.ellipse(
            [vp_x - rx, vp_y - ry, vp_x + rx, vp_y + ry],
            fill=color
        )

    glow_blurred = glow_img.filter(ImageFilter.GaussianBlur(radius=30))
    img.paste(glow_blurred, (0, 0), glow_blurred)


def draw_forest_silhouette(img):
    """Pine tree silhouettes at the horizon."""
    draw = ImageDraw.Draw(img)
    horizon_y = int(SIZE * 0.55)
    tree_color = (20, 50, 20)  # near-black dark green

    def draw_pine(cx, base_y, height, width_factor=1.0):
        """Draw a simple layered pine tree."""
        layers = 4
        for layer in range(layers):
            t = layer / (layers - 1)
            layer_h = height * (0.45 - t * 0.1)
            layer_w = int(width_factor * height * (0.22 + t * 0.18))
            layer_y = base_y - height + int(height * t * 0.65)
            pts = [
                (cx, layer_y - layer_h),
                (cx - layer_w, layer_y),
                (cx + layer_w, layer_y),
            ]
            draw.polygon(pts, fill=tree_color)

    # Left forest bank
    left_trees = [
        (20, horizon_y + 10, 160, 0.9),
        (65, horizon_y + 5, 140, 1.0),
        (110, horizon_y + 8, 175, 0.85),
        (150, horizon_y + 3, 130, 1.1),
        (195, horizon_y + 12, 155, 0.9),
        (235, horizon_y + 6, 145, 1.0),
        (275, horizon_y + 10, 120, 0.95),
        (315, horizon_y + 4, 135, 1.0),
        (350, horizon_y + 8, 100, 1.1),
        (385, horizon_y + 6, 85, 0.9),
    ]
    # Right forest bank (mirror-ish with variation)
    right_trees = [
        (SIZE - 20,  horizon_y + 10, 160, 0.9),
        (SIZE - 65,  horizon_y + 5,  140, 1.0),
        (SIZE - 110, horizon_y + 8,  175, 0.85),
        (SIZE - 150, horizon_y + 3,  130, 1.1),
        (SIZE - 195, horizon_y + 12, 155, 0.9),
        (SIZE - 235, horizon_y + 6,  145, 1.0),
        (SIZE - 275, horizon_y + 10, 120, 0.95),
        (SIZE - 315, horizon_y + 4,  135, 1.0),
        (SIZE - 350, horizon_y + 8,  100, 1.1),
        (SIZE - 385, horizon_y + 6,   85, 0.9),
    ]

    for args in left_trees + right_trees:
        draw_pine(*args)


def draw_road(img):
    """Perspective road: wide trapezoid from bottom center to vanishing point."""
    draw = ImageDraw.Draw(img)

    vp_x = SIZE // 2
    horizon_y = int(SIZE * 0.55)
    bottom_y = SIZE

    road_bottom_half_w = 280   # half-width at very bottom
    road_horizon_half_w = 16   # half-width at horizon

    # Main road surface
    road_pts = [
        (vp_x - road_horizon_half_w, horizon_y),
        (vp_x + road_horizon_half_w, horizon_y),
        (vp_x + road_bottom_half_w, bottom_y),
        (vp_x - road_bottom_half_w, bottom_y),
    ]
    draw.polygon(road_pts, fill=(42, 42, 42))

    # Subtle asphalt shading — slightly lighter center strip
    center_pts = [
        (vp_x - road_horizon_half_w // 2, horizon_y),
        (vp_x + road_horizon_half_w // 2, horizon_y),
        (vp_x + road_bottom_half_w // 2, bottom_y),
        (vp_x - road_bottom_half_w // 2, bottom_y),
    ]
    # draw subtle lighter center
    center_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    center_draw = ImageDraw.Draw(center_img)
    center_draw.polygon(center_pts, fill=(55, 55, 55, 60))
    img.paste(center_img, (0, 0), center_img)

    # Road shoulders (slightly lighter edge strip)
    shoulder_w = 18
    left_shoulder = [
        (vp_x - road_horizon_half_w, horizon_y),
        (vp_x - road_horizon_half_w + 3, horizon_y),
        (vp_x - road_bottom_half_w + shoulder_w, bottom_y),
        (vp_x - road_bottom_half_w, bottom_y),
    ]
    right_shoulder = [
        (vp_x + road_horizon_half_w - 3, horizon_y),
        (vp_x + road_horizon_half_w, horizon_y),
        (vp_x + road_bottom_half_w, bottom_y),
        (vp_x + road_bottom_half_w - shoulder_w, bottom_y),
    ]
    draw.polygon(left_shoulder, fill=(68, 65, 55))
    draw.polygon(right_shoulder, fill=(68, 65, 55))


def draw_center_dashes(img):
    """Perspective dashed center line on road."""
    draw = ImageDraw.Draw(img)

    vp_x = SIZE // 2
    horizon_y = int(SIZE * 0.55)
    bottom_y = SIZE

    road_bottom_half_w = 280
    road_horizon_half_w = 16

    dash_color = (212, 180, 131)   # #D4B483 warm parchment

    # Draw dashes at intervals along the road in perspective
    num_dashes = 10
    for i in range(num_dashes):
        t_start = i / num_dashes
        t_end = (i + 0.45) / num_dashes  # dash is ~45% of interval

        # Interpolate y positions
        y_start = horizon_y + int((bottom_y - horizon_y) * t_start)
        y_end = horizon_y + int((bottom_y - horizon_y) * t_end)

        # Road half-width at these y positions (linear interpolation)
        def road_hw(y):
            t = (y - horizon_y) / (bottom_y - horizon_y)
            return road_horizon_half_w + (road_bottom_half_w - road_horizon_half_w) * t

        w_start = road_hw(y_start) * 0.04  # dash width scales with road
        w_end = road_hw(y_end) * 0.04

        # Draw as trapezoid
        dash_pts = [
            (vp_x - w_start, y_start),
            (vp_x + w_start, y_start),
            (vp_x + w_end, y_end),
            (vp_x - w_end, y_end),
        ]
        draw.polygon(dash_pts, fill=dash_color)


def draw_rider_silhouette(img):
    """Small motorcycle+rider silhouette centered on road."""
    draw = ImageDraw.Draw(img)

    cx = SIZE // 2
    # Place rider ~28% up from bottom
    base_y = int(SIZE * 0.78)

    # Scale: the rider should feel tiny against the landscape
    scale = 38  # pixels for wheel radius reference
    rider_color = (13, 31, 13)  # #0D1F0D near black

    # --- Rear wheel ---
    rw_r = int(scale * 0.55)
    rw_cx = cx - int(scale * 0.7)
    rw_cy = base_y
    draw.ellipse(
        [rw_cx - rw_r, rw_cy - rw_r, rw_cx + rw_r, rw_cy + rw_r],
        fill=rider_color
    )
    draw.ellipse(
        [rw_cx - int(rw_r * 0.45), rw_cy - int(rw_r * 0.45),
         rw_cx + int(rw_r * 0.45), rw_cy + int(rw_r * 0.45)],
        fill=(42, 42, 42)
    )

    # --- Front wheel ---
    fw_r = int(scale * 0.5)
    fw_cx = cx + int(scale * 0.85)
    fw_cy = base_y
    draw.ellipse(
        [fw_cx - fw_r, fw_cy - fw_r, fw_cx + fw_r, fw_cy + fw_r],
        fill=rider_color
    )
    draw.ellipse(
        [fw_cx - int(fw_r * 0.42), fw_cy - int(fw_r * 0.42),
         fw_cx + int(fw_r * 0.42), fw_cy + int(fw_r * 0.42)],
        fill=(42, 42, 42)
    )

    # --- Frame body (main bike body) ---
    frame_pts = [
        (rw_cx + rw_r - 4, rw_cy - int(scale * 0.3)),   # rear low
        (rw_cx + rw_r, rw_cy - int(scale * 0.85)),        # rear high / seat
        (cx + int(scale * 0.1), rw_cy - int(scale * 0.95)),  # tank top
        (fw_cx - fw_r + 6, fw_cy - int(scale * 0.4)),    # front low
        (fw_cx - fw_r + 2, fw_cy - int(scale * 0.15)),   # front fork base
    ]
    draw.polygon(frame_pts, fill=rider_color)

    # --- Exhaust / lower frame ---
    exhaust_pts = [
        (rw_cx + rw_r - 2, rw_cy - int(scale * 0.2)),
        (fw_cx - fw_r + 4, fw_cy - int(scale * 0.2)),
        (fw_cx - fw_r + 4, fw_cy - int(scale * 0.35)),
        (rw_cx + rw_r - 2, rw_cy - int(scale * 0.35)),
    ]
    draw.polygon(exhaust_pts, fill=rider_color)

    # --- Fork / front suspension ---
    fork_pts = [
        (fw_cx - int(scale * 0.12), fw_cy - fw_r),
        (fw_cx + int(scale * 0.08), fw_cy - fw_r),
        (fw_cx + int(scale * 0.04), fw_cy - int(scale * 0.8)),
        (fw_cx - int(scale * 0.16), fw_cy - int(scale * 0.8)),
    ]
    draw.polygon(fork_pts, fill=rider_color)

    # --- Rider body (crouched riding position) ---
    body_cx = cx - int(scale * 0.05)
    body_base = rw_cy - int(scale * 0.9)

    # Torso (leaning forward)
    torso_pts = [
        (body_cx - int(scale * 0.2), body_base),                 # seat left
        (body_cx + int(scale * 0.15), body_base),                # seat right
        (body_cx + int(scale * 0.4), body_base - int(scale * 0.55)),  # shoulder right
        (body_cx + int(scale * 0.15), body_base - int(scale * 0.65)), # neck
        (body_cx - int(scale * 0.1), body_base - int(scale * 0.5)),   # shoulder left
    ]
    draw.polygon(torso_pts, fill=rider_color)

    # Head (helmet) — slightly forward of torso
    head_cx = body_cx + int(scale * 0.28)
    head_cy = body_base - int(scale * 0.85)
    head_r = int(scale * 0.28)
    draw.ellipse(
        [head_cx - head_r, head_cy - head_r,
         head_cx + head_r, head_cy + int(head_r * 0.8)],
        fill=rider_color
    )

    # Arms reaching to handlebars
    arm_pts = [
        (body_cx + int(scale * 0.35), body_base - int(scale * 0.5)),
        (fw_cx - int(scale * 0.08), fw_cy - int(scale * 0.75)),
        (fw_cx + int(scale * 0.05), fw_cy - int(scale * 0.7)),
        (body_cx + int(scale * 0.45), body_base - int(scale * 0.45)),
    ]
    draw.polygon(arm_pts, fill=rider_color)

    # Handlebar
    hbar_y = fw_cy - int(scale * 0.78)
    draw.rectangle(
        [fw_cx - int(scale * 0.25), hbar_y - 3,
         fw_cx + int(scale * 0.18), hbar_y + 3],
        fill=rider_color
    )


def draw_vignette(img):
    """Subtle dark vignette around edges to focus the eye to center."""
    vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(vignette)

    # Several concentric rectangles with increasing alpha
    steps = 18
    for i in range(steps):
        t = i / steps
        alpha = int(80 * (t ** 2))  # quadratic falloff
        margin = int(SIZE * 0.5 * (1 - t))
        draw.rectangle(
            [SIZE // 2 - margin, SIZE // 2 - margin,
             SIZE // 2 + margin, SIZE // 2 + margin],
            outline=(0, 0, 0, 0)
        )

    # Radial vignette via ellipse mask
    for i in range(steps):
        t = (steps - i) / steps
        alpha = int(110 * (1 - t) ** 2.5)
        rx = int(SIZE * 0.45 + SIZE * 0.5 * (1 - t))
        ry = int(SIZE * 0.45 + SIZE * 0.5 * (1 - t))
        x0 = SIZE // 2 - rx
        y0 = SIZE // 2 - ry
        draw.ellipse([x0, y0, x0 + rx * 2, y0 + ry * 2],
                     outline=(0, 0, 0, alpha), width=int(SIZE * 0.03))

    vignette_blurred = vignette.filter(ImageFilter.GaussianBlur(radius=40))
    img.paste(vignette_blurred, (0, 0), vignette_blurred)


def apply_ios_rounded_corners(img, radius_fraction=0.2236):
    """Apply iOS icon rounded corners (squircle approximation via mask)."""
    radius = int(SIZE * radius_fraction)
    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255)
    mask_blurred = mask.filter(ImageFilter.GaussianBlur(radius=1))
    result = img.copy().convert("RGBA")
    result.putalpha(mask_blurred)
    return result


def main():
    print("ZenRide Icon Generator — Zen Rider + Open Road")
    print(f"Output: {os.path.abspath(OUTPUT_PATH)}")

    img = Image.new("RGB", (SIZE, SIZE), (26, 61, 26))
    img = img.convert("RGBA")

    print("  Drawing sky gradient...")
    draw_sky_gradient(img)

    print("  Drawing ground/forest gradient...")
    draw_ground_gradient(img)

    print("  Drawing sun glow...")
    draw_sun_glow(img)

    print("  Drawing mist band...")
    draw_mist_band(img)

    print("  Drawing forest silhouettes...")
    draw_forest_silhouette(img)

    print("  Drawing road...")
    draw_road(img)

    print("  Drawing center dashes...")
    draw_center_dashes(img)

    print("  Drawing rider silhouette...")
    draw_rider_silhouette(img)

    print("  Applying vignette...")
    draw_vignette(img)

    print("  Applying iOS rounded corners...")
    img = apply_ios_rounded_corners(img)

    # Flatten to RGB for PNG (white background for any transparency)
    final = Image.new("RGB", (SIZE, SIZE), (255, 255, 255))
    final.paste(img, (0, 0), img)

    os.makedirs(os.path.dirname(os.path.abspath(OUTPUT_PATH)), exist_ok=True)
    final.save(OUTPUT_PATH, "PNG", optimize=False)
    print(f"  Done. Saved {SIZE}x{SIZE} PNG.")
    print()
    print(f"  open \"{os.path.abspath(OUTPUT_PATH)}\"")


if __name__ == "__main__":
    main()
