import sys
import os
from PIL import Image

def color_dist(c1, c2):
    return sum((a - b) ** 2 for a, b in zip(c1[:3], c2[:3]))

def process_image(input_path, output_path):
    print(f"Processing {input_path}...")
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    # Assume top-left pixel is the background color (should be magenta)
    bg_color = pixels[0, 0]
    
    # Check if it's close to magenta (255, 0, 255)
    if color_dist(bg_color, (255, 0, 255)) > 10000:
        print(f"Warning: Top-left color {bg_color} might not be pure magenta, but proceeding anyway.")

    visited = set()
    queue = [(0, 0)]
    visited.add((0, 0))
    
    # Tolerance for compression artifacts in the generated image
    tolerance_sq = 80 * 80 
    
    while queue:
        x, y = queue.pop(0)
        # Make transparent
        pixels[x, y] = (0, 0, 0, 0)
        
        # Check neighbors
        for dx, dy in [(0, 1), (1, 0), (0, -1), (-1, 0)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                if color_dist(pixels[nx, ny], bg_color) < tolerance_sq:
                    visited.add((nx, ny))
                    queue.append((nx, ny))
                    
    # Auto-crop the image to the non-transparent bounding box
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        print(f"Cropped to bounding box: {bbox}")
        width, height = img.size
        
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"Success! Saved to {output_path}. Final dimensions: {width}x{height}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python process_transparency.py <input> <output>")
        sys.exit(1)
    process_image(sys.argv[1], sys.argv[2])
