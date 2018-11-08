This is an example of a simple tool to tranform PNG files to ensure that solid content is centered and shaded content is kept
Also cleans garbage transparency data.

Usage
./ensure source-folder destination-folder content-csv filename-column path-column (scale%)

source folder is a file structure that contains all images that are named in the content csv
destination folder is a new folder structure that will be created given the content in the content csv
filename-column specifies which column contains the png filename
path-column specifies which column contains the output path for the processed filename
scale *optional* an integer between 1 and 100 
    *requires mogrify installed on your system (part of ImageMagick)

assumes 2 rows as headers

content-csv is of any format, but has the 3 columns in this order:
* skip (boolean)
* filename
* destination path

so something like this example.csv:
```
row, skip, filename, path
count,,,
1, false, image_1.png, man/standing
2, false, image_2.png, woman/sitting
3, true, image_3.png, dog
```
this then could then be called like this:

./ensure.rb broken fixed example.csv 3 4