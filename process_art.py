import sys
import os
import argparse
from PIL import Image
from collections import deque

def color_dist_sq(c1, c2):
    return sum((a - b) ** 2 for a, b in zip(c1[:3], c2[:3]))

def process_image(input_path, output_path, crop=True, tolerance=80):
    print(f"Processing {input_path} -> {output_path} (crop={crop}, tolerance={tolerance})...")
    img = Image.open(input_path).convert("RGB")
    width, height = img.size
    pixels = img.load()
    
    # Pure magenta chroma-key reference
    CHROMA_MAGENTA = (255, 0, 255)
    
    # Sample 4 corners
    corners = [pixels[0, 0], pixels[width-1, 0], pixels[0, height-1], pixels[width-1, height-1]]
    bg_color = pixels[0, 0]
    
    # Check if corner is close to magenta
    is_magenta = any(color_dist_sq(c, CHROMA_MAGENTA) < 4000 for c in corners)
    if is_magenta:
        bg_ref = CHROMA_MAGENTA
        tolerance_sq = tolerance * tolerance
        print("Detected Magenta Chroma Key background.")
    else:
        bg_ref = bg_color
        tolerance_sq = tolerance * tolerance
        print(f"Using border color {bg_ref} as chroma reference (tolerance={tolerance}).")

    visited = [[False]*height for _ in range(width)]
    queue = deque()

    # Seed all 4 borders
    for x in range(width):
        for y in [0, height-1]:
            if not visited[x][y] and color_dist_sq(pixels[x, y], bg_ref) <= tolerance_sq:
                visited[x][y] = True
                queue.append((x, y))

    for y in range(height):
        for x in [0, width-1]:
            if not visited[x][y] and color_dist_sq(pixels[x, y], bg_ref) <= tolerance_sq:
                visited[x][y] = True
                queue.append((x, y))

    # Flood fill background
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < width and 0 <= ny < height and not visited[nx][ny]:
                if color_dist_sq(pixels[nx, ny], bg_ref) <= tolerance_sq:
                    visited[nx][ny] = True
                    queue.append((nx, ny))

    # Construct clean RGBA with 100% solid foreground
    out_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out_pixels = out_img.load()
    
    opaque_pixels = 0
    for x in range(width):
        for y in range(height):
            if not visited[x][y]:
                r, g, b = pixels[x, y]
                out_pixels[x, y] = (r, g, b, 255)
                opaque_pixels += 1

    if crop:
        bbox = out_img.getbbox()
        if bbox:
            out_img = out_img.crop(bbox)
            print(f"Auto-cropped to bounding box: {bbox} (new size: {out_img.size})")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    out_img.save(output_path, "PNG")
    print(f"Success! Saved {output_path} (opaque pixels: {opaque_pixels}, final size: {out_img.size})")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Chroma-key background extractor for game sprites.")
    parser.add_argument("input", help="Input image path (JPG or PNG with magenta/chroma background)")
    parser.add_argument("output", help="Output PNG path")
    parser.add_argument("--no-crop", action="store_true", help="Preserve full original canvas size (do not auto-crop)")
    parser.add_argument("--tolerance", type=int, default=80, help="Chroma key color tolerance (default: 80)")
    
    args = parser.parse_args()
    process_image(args.input, args.output, crop=not args.no_crop, tolerance=args.tolerance)
