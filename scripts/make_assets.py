"""Generates the asset catalogs (app icon, accent colour, launch background) for iOS and watchOS."""
import json, os, sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1]

def icon(path, size=1024):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    top, bottom = (255, 106, 61), (233, 30, 99)   # coral -> pink
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    w = (255, 255, 255)
    c = size / 2
    # dumbbell: bar + two plates each side
    bar_h = size * 0.07
    d.rounded_rectangle([c - size*0.30, c - bar_h/2, c + size*0.30, c + bar_h/2], radius=bar_h/2, fill=w)
    for sgn in (-1, 1):
        x_outer = c + sgn * size * 0.30
        for (off, h, wd) in ((0.0, 0.42, 0.075), (0.09, 0.30, 0.06)):
            x = x_outer + sgn * size * off if off else x_outer - sgn * size * 0.0
            x0 = c + sgn * size * (0.22 + off) - size*wd/2
            d.rounded_rectangle([x0, c - size*h/2, x0 + size*wd, c + size*h/2], radius=size*0.025, fill=w)
    img.save(path)

def write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)

def color(r, g, b, dark=None):
    def comp(rgb):
        return {"color-space": "srgb", "components": {"red": f"{rgb[0]/255:.3f}", "green": f"{rgb[1]/255:.3f}", "blue": f"{rgb[2]/255:.3f}", "alpha": "1.000"}}
    colors = [{"idiom": "universal", "color": comp((r, g, b))}]
    if dark:
        colors.append({"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}], "color": comp(dark)})
    return {"colors": colors, "info": {"author": "xcode", "version": 1}}

for platform in ("iOS", "Watch"):
    cat = os.path.join(ROOT, platform, "Resources", "Assets.xcassets")
    write(os.path.join(cat, "Contents.json"), {"info": {"author": "xcode", "version": 1}})
    appicon = os.path.join(cat, "AppIcon.appiconset")
    os.makedirs(appicon, exist_ok=True)
    icon(os.path.join(appicon, "AppIcon.png"))
    plat = "ios" if platform == "iOS" else "watchos"
    write(os.path.join(appicon, "Contents.json"), {
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": plat, "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1}})
    write(os.path.join(cat, "AccentColor.colorset", "Contents.json"), color(255, 87, 51, dark=(255, 112, 77)))
    if platform == "iOS":
        write(os.path.join(cat, "LaunchBackground.colorset", "Contents.json"), color(255, 255, 255, dark=(0, 0, 0)))
print("ok")
