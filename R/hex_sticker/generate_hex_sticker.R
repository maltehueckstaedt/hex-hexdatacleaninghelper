# load the necessary packages
library(hexSticker) # hexSticker generator
library(magick)     # Advanced image processing
library(sysfonts)   # font selection
library(tidyverse)


pine_img <- image_read('img/cleaning.png')

fonts_dataset <- font_files()

# Füge die Pastelaria-Schriftart hinzu
font_add("Brandon", "C:/Users/mhu/AppData/Local/Microsoft/Windows/Fonts/HVD Fonts - BrandonText-Regular.ttf")


# Sticker mit der Pastelaria-Schriftart erstellen
sticker(
  subplot = pine_img,
  package = "SVCleanR",
  s_width = 0.8,   # kleiner gemacht
  s_height = 0.8,  # kleiner gemacht
  s_x = 1,
  s_y = 0.75,
  p_size = 25,
  h_fill = '#87dff7',
  h_color = 'hotpink',
  h_size = 4,      # dickerer Rand
  p_color = '#13011f',
  p_family = "Brandon"
) %>% print()