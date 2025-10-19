#!/usr/bin/env python3
"""
Resize KAGRI logo to all required Android icon sizes
"""
from PIL import Image
import os

# Define sizes for Android icon densities
sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

# Input logo path (user needs to provide)
logo_paths = [
    'assets/475878905_122213763782224521_6121706232536862414_n.jpg',
    'assets/kagri_logo.png',
    'assets/kagri_logo.jpg',
    './kagri_logo.png',
    '../kagri_logo.png',
]

source_img = None
for path in logo_paths:
    if os.path.exists(path):
        source_img = path
        print(f"✅ Found logo at: {path}")
        break

if not source_img:
    print("❌ Logo not found!")
    print("Please place kagri_logo.png in one of these locations:")
    for path in logo_paths:
        print(f"  - {path}")
    exit(1)

# Open the logo
img = Image.open(source_img).convert('RGBA')
print(f"📦 Original size: {img.size}")

# Resize for each density
android_res_path = 'android/app/src/main/res'
for density, size in sizes.items():
    output_dir = os.path.join(android_res_path, density)
    output_path = os.path.join(output_dir, 'ic_launcher.png')
    
    # Resize image
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    
    # Save
    resized.save(output_path, 'PNG')
    print(f"✅ Created {density} ({size}x{size}): {output_path}")

print("\n✅ All Android icons created successfully!")
print("\n📱 For iOS, you need to manually update:")
print("  ios/Runner/Assets.xcassets/AppIcon.appiconset/")
print("  (Use XCode or App Icon Maker tool)")
