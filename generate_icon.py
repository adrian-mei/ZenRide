import math

svg = []
svg.append('<?xml version="1.0" encoding="utf-8"?>')
svg.append('<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">')

svg.append('<defs>')

# Sky Gradient
svg.append('''<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#1A0000"/>
    <stop offset="40%" stop-color="#6E1500"/>
    <stop offset="70%" stop-color="#E25400"/>
    <stop offset="100%" stop-color="#FF9D00"/>
</linearGradient>''')

# Ground Gradient
svg.append('''<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#0E2108"/>
    <stop offset="100%" stop-color="#050A02"/>
</linearGradient>''')

svg.append('</defs>')

# Sky
svg.append('<rect width="1024" height="1024" fill="url(#sky)" />')

# Banded Sun
svg.append('<circle cx="512" cy="480" r="140" fill="#E2C431" />')
svg.append('<circle cx="512" cy="480" r="100" fill="#F5E78C" />')
svg.append('<circle cx="512" cy="480" r="60" fill="#FFFFFF" />')

# Ground
svg.append('<rect x="0" y="480" width="1024" height="544" fill="url(#ground)" />')

# Road
svg.append('<polygon points="492,480 532,480 880,1024 144,1024" fill="#141416" />')
# Road Edges
svg.append('<polygon points="492,480 144,1024 124,1024" fill="#0C0C0D" />')
svg.append('<polygon points="532,480 880,1024 900,1024" fill="#0C0C0D" />')

# Road Dashes
dashes = [
    (510, 500, 514, 500, 513, 530, 511, 530),
    (509, 560, 515, 560, 513, 610, 511, 610),
    (507, 650, 517, 650, 515, 720, 509, 720),
    (504, 780, 520, 780, 517, 870, 507, 870),
    (500, 940, 524, 940, 520, 1024, 504, 1024)
]
for d in dashes:
    svg.append(f'<polygon points="{d[0]},{d[1]} {d[2]},{d[3]} {d[4]},{d[5]} {d[6]},{d[7]}" fill="#C8972F" />')

# Trees (Flat Dark Green Triangles)
# Back to front for correct overlapping
tree_color = "#082110"
tree_shadow = "#041008"

# Generate tree arrays
left_trees = []
right_trees = []

for i in range(12):
    # Logarithmic-ish spacing
    t = (i / 11.0)
    t = t * t # closer near the horizon
    
    y = 480 + t * 500
    x_l = 480 - t * 400
    x_r = 544 + t * 400
    
    # Size scaling
    size = 0.2 + t * 2.5
    w = 60 * size
    h = 240 * size
    
    left_trees.append((x_l, y, w, h))
    right_trees.append((x_r, y, w, h))

# Sort by Y ascending (draw back to front)
left_trees.sort(key=lambda x: x[1])
right_trees.sort(key=lambda x: x[1])

for (x, y, w, h) in left_trees:
    svg.append(f'<polygon points="{x},{y-h} {x-w/2},{y} {x+w/2},{y}" fill="{tree_color}" />')
    # Right-side shadow on left tree
    svg.append(f'<polygon points="{x},{y-h} {x},{y} {x+w/2},{y}" fill="{tree_shadow}" />')

for (x, y, w, h) in right_trees:
    svg.append(f'<polygon points="{x},{y-h} {x-w/2},{y} {x+w/2},{y}" fill="{tree_color}" />')
    # Right-side shadow on right tree
    svg.append(f'<polygon points="{x},{y-h} {x},{y} {x+w/2},{y}" fill="{tree_shadow}" />')


# Sleek Motorcycle Silhouette
# A sharp, sporty silhouette from the rear
# Translated and scaled
svg.append('''
<g transform="translate(432, 700) scale(1.6)">
    <!-- Rear Tire -->
    <path d="M 40 100 C 35 100, 30 110, 30 130 C 30 150, 35 160, 40 160 C 55 160, 65 150, 65 130 C 65 110, 55 100, 40 100 Z" fill="#000000" />
    <!-- Highlight on Tire -->
    <path d="M 38 105 C 36 105, 33 115, 33 130 C 33 145, 36 155, 38 155 C 40 155, 42 145, 42 130 C 42 115, 40 105, 38 105 Z" fill="#151515" />
    
    <!-- Tail Section & Exhaust -->
    <path d="M 25 70 L 65 70 L 70 85 L 60 100 L 25 100 Z" fill="#1A1A1A" />
    <path d="M 70 85 L 85 95 L 80 110 L 60 100 Z" fill="#111111" />
    
    <!-- Taillight -->
    <path d="M 35 75 L 55 75 L 52 80 L 38 80 Z" fill="#FF2A00" />
    <!-- Taillight Glow -->
    <path d="M 35 75 L 55 75 L 52 80 L 38 80 Z" fill="#FF5500" filter="blur(2px)" opacity="0.8" />
    
    <!-- Rider Body -->
    <path d="M 45 65 C 55 65, 70 50, 60 25 C 50 0, 30 0, 20 25 C 10 50, 30 65, 45 65 Z" fill="#0A0A0A" />
    
    <!-- Helmet -->
    <circle cx="45" cy="15" r="14" fill="#050505" />
    <!-- Helmet Visor Reflection -->
    <path d="M 35 10 C 40 5, 50 5, 55 10 C 52 14, 38 14, 35 10 Z" fill="#2A2A2A" />
    
    <!-- Arms -->
    <path d="M 22 25 L 5 60 L 12 65 L 28 35 Z" fill="#0A0A0A" />
    <path d="M 68 25 L 85 60 L 78 65 L 62 35 Z" fill="#0A0A0A" />
    
    <!-- Bike Frame / Fairing sides -->
    <path d="M 12 65 L 25 90 L 30 75 Z" fill="#1F1F1F" />
    <path d="M 78 65 L 65 90 L 60 75 Z" fill="#1F1F1F" />
</g>
''')

svg.append('</svg>')

with open("icon.svg", "w") as f:
    f.write("\n".join(svg))
print("SVG Generated.")
