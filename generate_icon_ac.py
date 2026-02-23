import math

svg = []
svg.append('<?xml version="1.0" encoding="utf-8"?>')
svg.append('<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">')

svg.append('<defs>')

# AC Sky Gradient - soft sunset
svg.append('''<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#FFB39A"/>
    <stop offset="35%" stop-color="#FFCF9E"/>
    <stop offset="70%" stop-color="#FFE8A1"/>
    <stop offset="100%" stop-color="#FFF6D1"/>
</linearGradient>''')

# AC Ground Gradient - soft, warm grass
svg.append('''<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#A5DB7A"/>
    <stop offset="100%" stop-color="#88C25B"/>
</linearGradient>''')

# AC Road Gradient - warm light brown/gray
svg.append('''<linearGradient id="road" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#DCD0BD"/>
    <stop offset="100%" stop-color="#BEAFA1"/>
</linearGradient>''')

# Soft Sun
svg.append('''<radialGradient id="sun" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#FFFFFF"/>
    <stop offset="40%" stop-color="#FFFDF0"/>
    <stop offset="100%" stop-color="#FFF1B8" stop-opacity="0"/>
</radialGradient>''')

svg.append('</defs>')

# Background (Sky)
svg.append('<rect width="1024" height="1024" fill="url(#sky)" />')

# Sun
svg.append('<circle cx="512" cy="460" r="160" fill="url(#sun)" />')

# Distant Hills (overlapping soft curves)
svg.append('<path d="M 0 520 Q 150 450, 300 500 T 700 480 T 1024 520 L 1024 1024 L 0 1024 Z" fill="#B4DD8A" />')
svg.append('<path d="M 0 540 Q 200 490, 450 540 T 850 510 T 1024 550 L 1024 1024 L 0 1024 Z" fill="url(#ground)" />')

# Road (Curved, cute)
svg.append('<path d="M 480 520 Q 580 700, 200 1024 L 800 1024 Q 610 700, 540 520 Z" fill="url(#road)" />')

# Road details (edges, dashes)
svg.append('<path d="M 480 520 Q 580 700, 200 1024" stroke="#C5B6A3" stroke-width="12" fill="none" />')
svg.append('<path d="M 540 520 Q 610 700, 800 1024" stroke="#C5B6A3" stroke-width="12" fill="none" />')
svg.append('<path d="M 510 520 Q 595 700, 500 1024" stroke="#FFF8E7" stroke-width="16" stroke-dasharray="24,48" stroke-linecap="round" fill="none" opacity="0.9"/>')


# Trees
# AC style: Cedar and Oak
def get_cedar(x, y, scale):
    out = []
    # Shadow
    out.append(f'<ellipse cx="{x}" cy="{y}" rx="{45*scale}" ry="{15*scale}" fill="#6C9E44" opacity="0.5" />')
    # Trunk
    out.append(f'<rect x="{x-6*scale}" y="{y-20*scale}" width="{12*scale}" height="{30*scale}" rx="{4*scale}" fill="#8E6A51" />')
    # Tiers of leaves (from bottom to top)
    d1 = f"M {x-45*scale} {y-10*scale} Q {x} {y+10*scale} {x+45*scale} {y-10*scale} Q {x+50*scale} {y-20*scale} {x+40*scale} {y-35*scale} L {x+10*scale} {y-80*scale} Q {x} {y-90*scale} {x-10*scale} {y-80*scale} L {x-40*scale} {y-35*scale} Q {x-50*scale} {y-20*scale} {x-45*scale} {y-10*scale} Z"
    
    d2 = f"M {x-35*scale} {y-40*scale} Q {x} {y-25*scale} {x+35*scale} {y-40*scale} Q {x+40*scale} {y-50*scale} {x+30*scale} {y-65*scale} L {x+10*scale} {y-105*scale} Q {x} {y-115*scale} {x-10*scale} {y-105*scale} L {x-30*scale} {y-65*scale} Q {x-40*scale} {y-50*scale} {x-35*scale} {y-40*scale} Z"
    
    d3 = f"M {x-25*scale} {y-75*scale} Q {x} {y-65*scale} {x+25*scale} {y-75*scale} Q {x+30*scale} {y-85*scale} {x+20*scale} {y-100*scale} L {x+8*scale} {y-130*scale} Q {x} {y-140*scale} {x-8*scale} {y-130*scale} L {x-20*scale} {y-100*scale} Q {x-30*scale} {y-85*scale} {x-25*scale} {y-75*scale} Z"
    
    out.append(f'<path d="{d1}" fill="#4C8B47" />')
    out.append(f'<path d="{d2}" fill="#5CAB56" />')
    out.append(f'<path d="{d3}" fill="#6BD663" />')
    return "\\n".join(out)

def get_oak(x, y, scale):
    out = []
    out.append(f'<ellipse cx="{x}" cy="{y}" rx="{50*scale}" ry="{15*scale}" fill="#6C9E44" opacity="0.5" />')
    out.append(f'<rect x="{x-8*scale}" y="{y-30*scale}" width="{16*scale}" height="{40*scale}" rx="{4*scale}" fill="#8E6A51" />')
    # Clusters of circles
    out.append(f'<circle cx="{x-25*scale}" cy="{y-60*scale}" r="{35*scale}" fill="#4C8B47" />')
    out.append(f'<circle cx="{x+25*scale}" cy="{y-60*scale}" r="{35*scale}" fill="#4C8B47" />')
    out.append(f'<circle cx="{x}" cy="{y-85*scale}" r="{40*scale}" fill="#5CAB56" />')
    out.append(f'<circle cx="{x-15*scale}" cy="{y-45*scale}" r="{30*scale}" fill="#6BD663" />')
    out.append(f'<circle cx="{x+15*scale}" cy="{y-45*scale}" r="{30*scale}" fill="#6BD663" />')
    return "\\n".join(out)

# Place trees (back to front)
svg.append(get_oak(380, 560, 0.6))
svg.append(get_cedar(660, 550, 0.7))

svg.append(get_cedar(250, 630, 0.9))
svg.append(get_oak(780, 620, 0.9))

svg.append(get_oak(120, 760, 1.4))
svg.append(get_cedar(880, 740, 1.5))

svg.append(get_cedar(20, 960, 2.0))
svg.append(get_oak(960, 940, 1.9))


# Motorcycle Silhouette (Scooter/Cruiser style, cute rear view)
svg.append('''
<g transform="translate(390, 640) scale(2.6)">
    <!-- Shadow -->
    <ellipse cx="50" cy="85" rx="30" ry="10" fill="#BCAE9B" opacity="0.8" />
    
    <!-- Rear Tire -->
    <rect x="35" y="55" width="30" height="30" rx="12" fill="#4A4A4A" />
    <path d="M 38 60 Q 50 50, 62 60 L 60 80 Q 50 85, 40 80 Z" fill="#333333" />
    
    <!-- Fender/Tail -->
    <path d="M 25 45 Q 50 25, 75 45 Q 65 60, 50 55 Q 35 60, 25 45 Z" fill="#FF8D6D" />
    
    <!-- Seat -->
    <rect x="38" y="30" width="24" height="15" rx="8" fill="#5C4033" />
    
    <!-- Taillight -->
    <rect x="42" y="46" width="16" height="6" rx="3" fill="#FF5252" />
    
    <!-- Rider -->
    <!-- Torso / Jacket -->
    <path d="M 30 35 C 30 -5, 70 -5, 70 35 Z" fill="#6A9E96" />
    
    <!-- Arms -->
    <path d="M 35 20 Q 20 30, 25 45" stroke="#6A9E96" stroke-width="8" stroke-linecap="round" fill="none" />
    <path d="M 65 20 Q 80 30, 75 45" stroke="#6A9E96" stroke-width="8" stroke-linecap="round" fill="none" />
    
    <!-- Helmet -->
    <circle cx="50" cy="0" r="18" fill="#F4E8C1" />
    <!-- Helmet Stripe -->
    <path d="M 42 -17 L 58 -17 L 55 17 L 45 17 Z" fill="#E6A15C" />
    <!-- Helmet Bottom Trim -->
    <path d="M 32 0 A 18 18 0 0 0 68 0 L 32 0 Z" fill="#E6A15C" />
</g>
''')

svg.append('</svg>')

with open("icon.svg", "w") as f:
    f.write("\n".join(svg))
print("SVG Generated.")
