#!/bin/bash

tile_size=256
source="photo.jpg"
outputdir="./photo"
background="#444"
type="jpg"

rm -r "$outputdir"
mkdir "$outputdir"

args="-monitor -define registry:temporary-path=/var/tmp/image "
args=$args"-background "$background" -gravity center "

source_width=`identify -format "%w" $source`
source_height=`identify -format "%h" $source`
levels=`python -c "from math import *; print int(ceil(log(ceil(min($source_width,$source_height)/$tile_size),2))+1)"`
echo "Will make "$levels" levels"
echo

level=0
while [[ $level < $levels ]]; do
	leveldir="$outputdir/level$level"
	mkdir $leveldir
	if [[ $level == 0 ]]; then
		full_width=`python -c "import math; print int(math.ceil(1.0 * $source_width / (2 ** $levels)) * 2 ** $levels)"`
		full_height=`python -c "import math; print int(math.ceil(1.0 * $source_height / (2 ** $levels)) * 2 ** $levels)"`
		args=$args"( "$source" -strip -extent "$full_width"x"$full_height" ) "
	fi
	current_width=`python -c "print int($full_width / (2 ** $level))"`
	current_height=`python -c "print int($full_height / (2 ** $level))"`
	padded_width=`python -c "import math; print int((math.ceil($current_width/$tile_size)+1)*$tile_size)"`
	padded_height=`python -c "import math; print int((math.ceil($current_height/$tile_size)+1)*$tile_size)"`
	args=$args"( -clone 0 -scale "$current_width"x"$current_height" -extent "$padded_width"x"$padded_height" \
	-crop "$tile_size"x"$tile_size" +repage -write "$leveldir"/tile-%d."$type" ) "
	
	cols_in_level[$level]=`echo "$padded_width / $tile_size" | bc`
	rows_in_level[$level]=`echo "$padded_height / $tile_size" | bc`
	tiles_in_level[$level]=$(( ${cols_in_level[$level]} * ${rows_in_level[$level]} ))
	
	level=$(( $level + 1 ))
done

args=$args" -delete 0 null:"

echo "about to run convert "$args
echo

echo $args | xargs convert

echo
echo "Writing json file"
cat > "$outputdir/settings.json" << ENDJS
{
	"root_dir" : "$outputdir", 
	"tile_size" : $tile_size,
	"levels" : $level,
	"tiles_in_level" : [`echo ${tiles_in_level[@]} | sed "s/ /, /g"`],
	"cols_in_level" : [`echo ${cols_in_level[@]} | sed "s/ /, /g"`],
	"rows_in_level" : [`echo ${rows_in_level[@]} | sed "s/ /, /g"`],
	"filetype" : "$type",
	"background_color" : "$background"
}
ENDJS