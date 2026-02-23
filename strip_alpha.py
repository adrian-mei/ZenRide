from PIL import Image

# Open the image
img = Image.open("./Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png")

# Convert to RGB (removes alpha channel)
if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
    alpha = img.convert('RGBA').split()[-1]
    bg = Image.new("RGB", img.size, (255, 255, 255))
    bg.paste(img, mask=alpha)
    bg.save("./Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png")
    print("Stripped alpha channel.")
else:
    print("No alpha channel found, or already RGB.")
