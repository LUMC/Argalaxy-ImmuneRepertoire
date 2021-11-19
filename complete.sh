#!/bin/bash
set -e
inputFiles=($1)  # Input files can be multiple files
outputDir=$3
outputFile=$3/index.html #$1
clonalType=$4
species=$5
locus=$6
filterproductive=$7
clonality_method=$8

html=$2
dir="$(cd "$(dirname "$0")" && pwd)"
array=("$@")
echo "<html><h3>Progress</h3><table><tr><td>info</td></tr>" > "$html"
echo "<tr><td>-----------------------------------</td></tr>" >> "$html"

#mkdir $PWD/igblastdatabase
#unzip $dir/database.zip -d $PWD/igblastdatabase/
#export IGDATA=$PWD/igblastdatabase/

echo "python: $(which python)"
echo "R: $(which R)"
echo "Rscript: $(which Rscript)"

id=""
forwardSlash="/"
mergerInput=()
echo "Before loop"
count=1
for current in "${inputFiles[@]}"
do
	if [[ "$current" != *"$forwardSlash"* ]]; then
			id="$current"
			mergerInput+=("$id")
			count=1
			continue
	fi
	echo "working on $current"
	fileName=$(basename "$current")
	fileName="${fileName%.*}"
	parsedFileName="$PWD/$fileName.parsed"
	f=$(file "$current")
	zipType="Zip archive"
	zxType="XZ compressed data"
	echo "filetype of ${id}: $f"
  	if [[ "$f" == *"$zipType"* ]] || [[ "$f" == *"$zxType"* ]]
	then
		echo "<tr><td>Sample $count of patient $id is an archive file, using IMGT Loader</td></tr>" >> $html
	  	fileName=$(basename $current)
		bash ${dir}/imgt_loader/imgt_loader.sh $current $parsedFileName "${fileName}"
	else
		echo "<tr><td>Sample $count of patient $id is not a zip file so assuming fasta/fastq, using igBLASTn</td></tr>" >> $html
		bash ${dir}/igblast/igblast.sh $current "$species" $locus $parsedFileName
	fi
	mergerInput+=("$parsedFileName")
	count=$((count+1))
done

echo "<tr><td>-----------------------------------</td></tr>" >> $html
echo "<tr><td>merging</td></tr>" >> $html

bash $dir/experimental_design/experimental_design.sh ${mergerInput[*]} $PWD/merged.txt

echo "<tr><td>done</td></tr>" >> $html
echo "<tr><td>-----------------------------------</td></tr>" >> $html
echo "<tr><td>plotting</td></tr>" >> $html

echo "after ED"

bash $dir/report_clonality/r_wrapper.sh $PWD/merged.txt $2 $outputDir $clonalType "$species" "$locus" $filterproductive $clonality_method

