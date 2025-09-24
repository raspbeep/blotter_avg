# open an image file with pillow and crop given coordinates
from PIL import Image


file_name = "signal.tiff"

im = Image.open(file_name)
crop = (329, 382, 329 + 55, 382 + 38)
print(crop)
cropped = im.crop(crop)
cropped.show()

# 5109.013

# calculate the average pixel value of the cropped image
pixels = list(cropped.getdata())
avg_pixel = sum(pixels) / len(pixels)
print(avg_pixel)
