import os
from PIL import Image, ImageDraw

def create_school_icon(size):
    # Create image with app background color #0F172A
    img = Image.new("RGBA", (size, size), "#0F172A")
    draw = ImageDraw.Draw(img)
    
    # Scale coordinates based on 512px canvas size
    scale = size / 512.0
    
    # Draw circular border (school rounded border shape)
    border_radius = 210 * scale
    center = size / 2.0
    draw.ellipse(
        [center - border_radius, center - border_radius, center + border_radius, center + border_radius],
        outline="#2DD4BF",
        width=int(12 * scale)
    )
    
    # Draw graduation cap skull cap base
    # Coordinates scaled from 512px target
    base_points = [
        (192 * scale, 274 * scale),
        (192 * scale, 330 * scale),
        (256 * scale, 360 * scale),
        (320 * scale, 330 * scale),
        (320 * scale, 274 * scale),
        (256 * scale, 305 * scale)
    ]
    draw.polygon(base_points, fill="#0D9488", outline="#2DD4BF", width=int(6 * scale))
    
    # Draw graduation cap diamond top
    top_points = [
        (128 * scale, 230 * scale), # Left
        (256 * scale, 150 * scale), # Top
        (384 * scale, 230 * scale), # Right
        (256 * scale, 310 * scale)  # Bottom
    ]
    draw.polygon(top_points, fill="#2DD4BF", outline="#0D9488", width=int(4 * scale))
    
    # Draw tassel line and tassel end
    tassel_line = [
        (256 * scale, 230 * scale), # Center of diamond
        (150 * scale, 230 * scale), # Left edge of diamond
        (150 * scale, 320 * scale)  # Down to the side
    ]
    draw.line(tassel_line, fill="#2DD4BF", width=int(6 * scale), joint="round")
    
    tassel_end_radius = 12 * scale
    draw.ellipse(
        [
            150 * scale - tassel_end_radius, 
            320 * scale - tassel_end_radius,
            150 * scale + tassel_end_radius, 
            320 * scale + tassel_end_radius
        ],
        fill="#2DD4BF"
    )
    
    return img

def main():
    print("Generating web icons programmatically...")
    
    # Ensure directories exist
    os.makedirs("web/icons", exist_ok=True)
    
    # Generate favicon (512x512)
    img_512 = create_school_icon(512)
    img_512.save("web/favicon.png")
    img_512.save("web/icons/Icon-512.png")
    img_512.save("web/icons/Icon-maskable-512.png")
    
    # Generate 192x192 icons
    img_192 = create_school_icon(192)
    img_192.save("web/icons/Icon-192.png")
    img_192.save("web/icons/Icon-maskable-192.png")
    
    print("Icons successfully created.")

if __name__ == "__main__":
    main()
