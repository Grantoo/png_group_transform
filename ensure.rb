#!/usr/bin/env ruby

# #require 'chunky_png'
require 'oily_png'
require 'byebug'
require 'CSV'

folder = ARGV[0]
output_folder = ARGV[1]
csv_file = ARGV[2]
column = ARGV[3].to_i unless ARGV[3].nil?

if ARGV.count() < 4
  puts "ensure source-folder destination-folder csv-containing-file-names-and-destination-subfolder-mapping column-number"
  puts "  Will scour the source-folder for filenames contained in CSV"
  puts "  Will convert the filename and place in destination folder within subfolder"
  puts "  column-number specifies column in CSV that contains filenames - assumes that next column contains subfolder mappings, and previous column to contain a 'skip processing' boolean"
  puts "  Will identify any duplicate file names"
  puts "  Will identify missing files given file names"
  puts "  starts processing CSV on row 3 (2 header rows)"
  exit
end

folder += "/" unless folder.end_with?("/")
output_folder += "/" unless output_folder.end_with?("/")

puts "source folder: " + folder
puts "destination folder: " + output_folder

purple = ChunkyPNG::Color.opaque!(ChunkyPNG::Color::PREDEFINED_COLORS[:purple])
transparent_color = ChunkyPNG::Color::TRANSPARENT

def self.create_dir_if_not_exists(path)
  recursive = path.split('/')
  directory = ''
  recursive.each do |sub_directory|
    directory += sub_directory + '/'
    Dir.mkdir(directory) unless (File.directory? directory)
  end
end

filename_list = []
row_num = 0
CSV.foreach(csv_file) do |row|
  row_num += 1
  next if row_num <= 2 # skip first 2 rows

  filename = row[column]
  if filename.include?(filename)
    puts "duplicate filename: #{filename} in row #{row_num} -- skipping"
    next
  end

  if column > 0
    next if row[column - 1].to_s == 'true' or row[column - 1].to_s == 'TRUE'
  end

  output_path = row[column + 1]
  output_path += "/" unless output_path.end_with?("/")

  # locate file in source folder (assumed to be broken [or unprocessed])
  broken_name = Dir.glob("#{folder}/**/#{filename}")
  next if !broken_name.to_s.include?(".png")

  puts
  puts "broken: #{broken_name}"
  broken = ChunkyPNG::Image.from_file(broken_name)

  puts "width: #{broken.width}"
  puts "height: #{broken.height}"
  puts "pixels: #{broken.pixels.count}"

  # scan image line
  y_max = broken.height
  x_max = broken.width
  y_bottom = 0
  y_top = 0
  solid_top = y_max
  y_shadow = 0
  (y_max-1).downto(0).each do |y|
    line_has_shadow = false
    (0...x_max).each do |x|
      pixel = broken[x,y]
      # red = ChunkyPNG::Color.r(pixel)
      # green = ChunkyPNG::Color.g(pixel)
      # blue = ChunkyPNG::Color.b(pixel)
      alpha = ChunkyPNG::Color.a(pixel)
      opaque = ChunkyPNG::Color.opaque?(pixel)
      if opaque == false && alpha > 0 && alpha < 255
        line_has_shadow = true

        if y_shadow == 0 # shadow
          y_shadow = y
        end
      elsif opaque == false
        broken.set_pixel(x,y,transparent_color) # clean up image (garbage transparency)
      end
      if opaque == true
        solid_top = y
      end
      if opaque == true && y_bottom == 0
        y_bottom = y
      end
      # puts "#{x}: i:#{pixel.to_s(16)} r:#{red} g:#{green} b:#{blue} a:#{alpha} opaque:#{opaque.to_s}"
    end
    if line_has_shadow
      y_top = y
    end
  end

  x_left = 0
  x_right = 0
  solid_left = 0
  solid_right = 0
  (0...x_max).each do |x|
    line_has_shadow = false
    (0...y_max).each do |y|
      pixel = broken[x,y]
      alpha = ChunkyPNG::Color.a(pixel)
      opaque = ChunkyPNG::Color.opaque?(pixel)
      if opaque == false && alpha > 0
        line_has_shadow = true
        if x_left == 0 # shadow
          x_left = x
        end
      end
      if opaque == true
        solid_right = x
      end
      if opaque == true && solid_left == 0
        solid_left = x
      end
    end
    if line_has_shadow
      x_right = x
    end
  end

  puts
  puts broken_name
  puts "bottom at #{y_max} shadow ends at #{y_shadow} and object ends at #{y_bottom}"
  puts "top at #{solid_top} effects until #{y_top}"
  puts "solid image starts at #{solid_left} to #{solid_right}"
  puts "left starting at #{x_left} and effects ending at #{x_right}"
  puts "bottom shadow is #{y_shadow-y_bottom} high"
  puts "top transparency is #{solid_top} high"

  # crop accurately
  y_shadow_size = y_shadow - y_bottom
  y_calc = solid_top - y_shadow_size
  x_offset = 0
  y_offset = 0
  x_offset_start = 0
  y_offset_start = 0
  pixel_buffer = 1
  if y_calc < 0
    # TODO: need to add transparent buffer to top
    puts "add #{y_calc} to top"
    y_offset += y_calc.abs
    y_offset_start = y_offset
    y_calc = 0
  end
  x_start = x_left - 1
  if x_start < 0
    # TODO: need to add transparent buffer to left
    puts "add #{x_start} to left"
    x_offset += x_start.abs
    x_offset_start = x_offset
    x_start = 0
  end
  w = x_right - x_left + (pixel_buffer * 2)
  if ((x_start + w) >= x_max)
    # TODO: need to add transparent buffer to right
    puts "add #{(x_start + w) - x_max} to right"
    x_offset += (x_start + w) - x_max
  end
  h = y_shadow - y_calc + (pixel_buffer * 2)
  if h + y_offset >= y_max
    # TODO: need to add trasparent buffer to bottom
    puts "add #{(h + y_offset) - y_max} to bottom"
    y_offset += (h + y_offset) - y_max
  end

  bigger = ChunkyPNG::Image.new(x_max + x_offset + (pixel_buffer * 2), y_max + y_offset + (pixel_buffer * 2), ChunkyPNG::Color::TRANSPARENT)
  puts "bigger canvas is x=#{bigger.width} y=#{bigger.height}"
  puts "old canvas is x=#{broken.width} y=#{broken.height} at #{x_offset_start},#{y_offset_start}"
  broken = bigger.compose(broken,x_offset_start + pixel_buffer,y_offset_start + pixel_buffer)

  puts "calc = x:#{x_start} y:#{y_calc}, w:#{w}, h:#{h}"
  broken.crop!(x_start,y_calc,w + x_offset_start + (pixel_buffer * 2),h + y_offset_start + (pixel_buffer * 2))

  # break # first image only


  # puts "depth: #{broken.depth}"
  # puts "interlace: #{broken.interlace}"
  # puts "transparent_color: #{broken.transparent_color}"

  # ensure that output_path exists
  if !Dir.exists?(output_folder + output_path)
    create_dir_if_not_exists(output_folder + output_path)
  end

  # write out to file
  broken.save(output_folder + output_path + filename)
end

