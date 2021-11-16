#!/bin/bash

inputFile=$1
outputDir=$3
outputFile=$3/index.html #$2
clonalType=$4
species=$5
locus=$6
filterproductive=$7
clonality_method=$8

dir="$(cd "$(dirname "$0")" && pwd)"
useD="false"
if grep -q "$species.*${locus}D" "$dir/genes.txt" ; then
	echo "species D region in reference db"
	useD="true"
fi
echo "$species"
if [[ "$species" == *"custom"* ]] ; then
	loci=("${locus//;/ }")
	useD="true"
	echo "${loci[@]}"
	if [[ "${#loci[@]}" -eq "2" ]] ; then
		useD="false"
	fi
fi
mkdir $3
cp $dir/genes.txt $outputDir
Rscript --verbose $dir/RScript.r $inputFile $outputDir $outputDir $clonalType "$species" "$locus" $filterproductive ${clonality_method} 2>&1
cp $dir/tabber.js $outputDir
cp $dir/style.css $outputDir
cp $dir/script.js $outputDir
cp $dir/jquery-1.11.0.min.js $outputDir
cp $dir/pure-min.css $outputDir
cp $dir/IGH_junctie_analyse.png $outputDir
samples=`cat $outputDir/samples.txt`

echo "<html><center><h1><a href='index.html'>Click here for the results</a></h1>Tip: Open it in a new tab (middle mouse button or right mouse button -> 'open in new tab' on the link above)<br />" > $2
echo "<table border = 1>" >> $2
echo "<thead><tr><th>Donor/Replicate</th><th>All</th><th>Productive</th><th>Unique Productive</th><th>Unproductive</th><th>Unique Unproductive</th></tr></thead>" >> $2
while IFS=, read sample all productive perc_prod productive_unique perc_prod_un unproductive perc_unprod unproductive_unique perc_unprod_un
	do
		echo "<tr><td>$sample</td>" >> $2
		echo "<td>$all</td>" >> $2
		if [[ "$productive" != "0" ]] ; then
			echo "<td>$productive (${perc_prod}%)</td>" >> $2
			echo "<td>$productive_unique (${perc_prod_un}%)</td>" >> $2
			echo "<td>$unproductive (${perc_unprod}%)</td>" >> $2
			echo "<td>$unproductive_unique (${perc_unprod_un}%)</td></tr>" >> $2
		else
			echo "<td colspan='4' style='background-color: red;'>No productive sequences!</td>" >> $2
		fi
done < $outputDir/productive_counting.txt
echo "</table><br />" >> $2
echo "Table showing the number and percentage of (unique) productive and unproductive sequences per donor and per replicate. <br />" >> $2
echo "The definition of unique sequences is based on the clonal type definition filter setting chosen. " >> $2
echo "</center></html>" >> $2

echo "<html><head><title>Report on:" >> $outputFile

mkdir $outputDir/circos
cp -R $dir/circos/* $outputDir/circos/

USECIRCOS="no"
path_to_circos=$(which circos)
if [ -x "$path_to_circos" ]; then
	USECIRCOS="yes"
fi

echo "Using Circos: $USECIRCOS"
sed -i "s%DATA_DIR%$outputDir/circos%" $outputDir/circos/circos.conf
for sample in $samples; do #output the samples to a file and create the circos plots with the R script output
	echo " $sample" >> $outputFile
	
	if [[ "$USECIRCOS" != "yes" ]]; then
		continue
	fi
	
	circos_file="$outputDir/${sample}_VJ_circos.txt"
	sed -i -- 's%/%:%g' $circos_file
	echo -e -n "labels$(cat ${circos_file})" > ${circos_file}
	echo "Circos tools command:"
	echo "cat \"${circos_file}\" | parse-table -configfile $dir/circos/parse-table.conf 2>&1 | make-conf -dir $outputDir/circos/"
	cat "${circos_file}" | parse-table -configfile $dir/circos/parse-table.conf 2>&1 | make-conf -dir $outputDir/circos/

	echo "Circos command:"
	echo "circos -conf $outputDir/circos/circos.conf 2>&1"
	circos -conf $outputDir/circos/circos.conf 2>&1
	mv $outputDir/circos/circos.png $outputDir/circosVJ_${sample}.png
	mv $outputDir/circos/circos.svg $outputDir/circosVJ_${sample}.svg
	
	
	if [[ "$useD" == "true" ]] ; then
		circos_file="$outputDir/${sample}_VD_circos.txt"
		sed -i -- 's%/%:%g' $circos_file
		echo -e -n "labels$(cat ${circos_file})" > ${circos_file}
		cat "${circos_file}" | parse-table -configfile $dir/circos/parse-table.conf 2>&1 | make-conf -dir $outputDir/circos/
		sed -i -- 's%/%:%g' $outputDir/circos/cells.txt
		circos -conf $outputDir/circos/circos.conf 2>&1
		mv $outputDir/circos/circos.png $outputDir/circosVD_${sample}.png
		mv $outputDir/circos/circos.svg $outputDir/circosVD_${sample}.svg
		
		circos_file="$outputDir/${sample}_DJ_circos.txt"
		sed -i -- 's%/%:%g' $circos_file
		echo -e -n "labels$(cat ${circos_file})" > ${circos_file}
		cat "${circos_file}" | parse-table -configfile $dir/circos/parse-table.conf 2>&1 | make-conf -dir $outputDir/circos/
		sed -i -- 's%/%:%g' $outputDir/circos/cells.txt
		circos -conf $outputDir/circos/circos.conf 2>&1
		mv $outputDir/circos/circos.png $outputDir/circosDJ_${sample}.png
		mv $outputDir/circos/circos.svg $outputDir/circosDJ_${sample}.svg
	fi
done
echo "</title><script type='text/javascript' src='jquery-1.11.0.min.js'></script>" >> $outputFile
echo "<link rel='stylesheet' type='text/css' href='pure-min.css'>" >> $outputFile
echo "<script type='text/javascript' src='tabber.js'></script>" >> $outputFile
echo "<script type='text/javascript' src='script.js'></script>" >> $outputFile
echo "<link rel='stylesheet' type='text/css' href='style.css'></head>" >> $outputFile
echo "<div class='tabber'><div class='tabbertab' title='Gene frequencies'>" >> $outputFile


echo "<a href='VFPlot.pdf'><img src='VFPlot.png'/></a>" >> $outputFile
if [[ "$useD" == "true" ]] ; then
	echo "<a href='DFPlot.pdf'><img src='DFPlot.png'/></a>" >> $outputFile
fi
echo "<a href='VPlot.pdf'><img src='VPlot.png'/></a>" >> $outputFile
if [[ "$useD" == "true" ]] ; then
	echo "<a href='DPlot.pdf'><img src='DPlot.png'/></a>" >> $outputFile
fi
echo "<a href='JPlot.pdf'><img src='JPlot.png'/></a> <br />" >> $outputFile

echo "<a href='DReadingFrame.pdf'><img src='DReadingFrame.png'/></a>" >> $outputFile

cat $dir/naive_gene_freq.htm >> $outputFile

echo "</div>" >> $outputFile

echo "<div class='tabbertab' title='CDR3 Characteristics'>" >> $outputFile
echo "<a href='CDR3LengthPlot.pdf'><img src='CDR3LengthPlot.png'/></a><br />" >> $outputFile
echo "<a href='AAComposition.pdf'><img src='AAComposition.png'/></a>" >> $outputFile


echo "<table class='pure-table pure-table-striped'>" >> $outputFile
echo "<thead><tr><th>Donor</th><th>Median CDR3 Length</th></tr></thead>" >> $outputFile
while read Sample median
do
	echo "<tr><td>$Sample</td><td>$median</td></tr>" >> $outputFile
done < $outputDir/AAMedianBySample.txt
echo "</table>" >> $outputFile

cat $dir/naive_cdr3_char.htm >> $outputFile

echo "</div>" >> $outputFile

#Heatmaps

count=1
echo "<div class='tabbertab' title='Heatmaps'><div class='tabber'>" >> $outputFile
for sample in $samples; do
	echo "<div class='tabbertab' title='$sample'><table border='1'><tr>" >> $outputFile
	if [[ "$useD" == "true" ]] ; then
		echo "<td><a href='HeatmapVD_$sample.pdf'><img src='HeatmapVD_$sample.png'/></a></td>" >> $outputFile
	fi
	echo "<td><a href='HeatmapVJ_$sample.pdf'><img src='HeatmapVJ_$sample.png'/></a></td>" >> $outputFile
	if [[ "$useD" == "true" ]] ; then
		echo "<td><a href='HeatmapDJ_$sample.pdf'><img src='HeatmapDJ_$sample.png'/></a></td>" >> $outputFile
	fi
	echo "</tr></table></div>" >> $outputFile
	count=$((count+1))
done

cat $dir/naive_heatmap.htm >> $outputFile

echo "</div></div>" >> $outputFile

echo "<div class='tabbertab' title='Compare Heatmaps'><table class='pure-table pure-table-striped'><thead><tr><th>ID</th><th>Include</th></tr></thead>" >> $outputFile
for sample in $samples; do
	echo "<tr><td>$sample</td><td><input type='checkbox' onchange=\"javascript:compareAdd('$sample')\" id='compare_checkbox_$sample'/></td></tr>" >> $outputFile
done
echo "</table><div name='comparisonarea'>" >> $outputFile
echo "<table><tr id='comparison_table_vd'></tr></table>" >> $outputFile
echo "<table><tr id='comparison_table_vj'></tr></table>" >> $outputFile
echo "<table><tr id='comparison_table_dj'></tr></table>" >> $outputFile

cat $dir/naive_compare.htm >> $outputFile

echo "</div></div>" >> $outputFile


#circos

if [[ "$USECIRCOS" == "yes" ]]; then

	echo "<div class='tabbertab' title='Circos'><div class='tabber'>" >> $outputFile
	for sample in $samples; do
		echo "<div class='tabbertab' title='$sample'><table border='1'><center>" >> $outputFile
		if [[ "$useD" == "true" ]] ; then
			echo "<tr><td>V-D</td><td><a href='circosVD_${sample}.svg'><img src='circosVD_${sample}.png' width='700' height='700'/></td></tr>" >> $outputFile
		fi
		echo "<tr><td>V-J</td><td><a href='circosVJ_${sample}.svg'><img src='circosVJ_${sample}.png' width='700' height='700'/></td></tr>" >> $outputFile
		if [[ "$useD" == "true" ]] ; then
			echo "<tr><td>D-J</td><td><a href='circosDJ_${sample}.svg'><img src='circosDJ_${sample}.png' width='700' height='700'/></td></tr>" >> $outputFile
		fi
		echo "<center></table></div>" >> $outputFile
		count=$((count+1))
	done
	
	cat $dir/naive_circos.htm >> $outputFile
	
	echo "</div></div>" >> $outputFile
fi
#echo "<div class='tabbertab' title='Interactive'><svg class='chart'></svg><script src='http://d3js.org/d3.v3.min.js'></script></div>" >> $outputFile

hasReplicateColumn="$(if head -n 1 $inputFile | grep -q 'Replicate'; then echo 'Yes'; else echo 'No'; fi)"
echo "$hasReplicateColumn"
#if its a 'new' merged file with replicate info
if [[ "$hasReplicateColumn" == "Yes" && "${clonality_method}" != "none" ]] ; then
	if [[ "${clonality_method}" == "boyd" ]] ; then
		echo "<div class='tabbertab' title='Clonality'><div class='tabber'>" >> $outputFile
	else
		echo "<div class='tabbertab' title='Shared Clonal Types'><div class='tabber'>" >> $outputFile
	fi
	
	for sample in $samples; do
		echo "${clonality_method}"
		
		echo "<div class='tabbertab' title='$sample'><table class='pure-table pure-table-striped'>" >> $outputFile
		
		if [[ "${clonality_method}" == "boyd" ]] ; then
			clonalityScore="$(cat $outputDir/lymphclon_clonality_${sample}.txt)"
            echo "<tr><td>Clonality Score: </td><td>$clonalityScore</td></tr>" >> $outputFile
		fi
		
		#replicate,reads,squared
        echo "<tr><td>Replicate ID</td><td>Number of Sequences</td></tr>" >> $outputFile
        while read replicate reads squared
        do
            echo "<tr><td>$replicate</td><td>$reads</td></tr>" >> $outputFile
        done < $outputDir/ReplicateReads_$sample.txt
        
        #sum of reads and reads squared
        while read readsSum squaredSum
            do
                echo "<tr><td>Sum</td><td>$readsSum</td></tr>" >> $outputFile
        done < $outputDir/ReplicateSumReads_$sample.txt
        
        echo "<tr><td></td><td></td></tr>" >> $outputFile
        
        #overview
        echo "<tr><td>Number of replicates containing the coincidence</td><td>Number of sequences shared between replicates</td></tr>" >> $outputFile
        while read type count weight weightedCount
        do
            if [[ "$type" -eq "1" ]]; then
                echo "<tr><td>$type</td><td>$count</td></tr>" >> $outputFile
            else
                echo "<tr><td><a href='coincidences_${sample}_${type}.txt'>$type</a></td><td>$count</td></tr>" >> $outputFile
            fi
        done < $outputDir/ClonalityOverView_$sample.txt
        echo "</table></div>" >> $outputFile
	done
	
	cat $dir/naive_clonality.htm >> $outputFile
	
	echo "</div></div>" >> $outputFile
fi

#hasJunctionData="$(if head -n 1 $inputFile | grep -qE '3V.REGION.trimmed.nt.nb'; then echo 'Yes'; else echo 'No'; fi)"

#if [[ "$hasJunctionData" == "Yes" ]] ; then
if [ -a "$outputDir/junctionAnalysisProd_mean_wD.txt" ] ; then
	echo "<div class='tabbertab' title='Junction Analysis'>" >> $outputFile
	echo "<img src='IGH_junctie_analyse.png' />" >> $outputFile
	
	echo "<center><p style='font-size: 20;'>Unique rearrangements with a V, D and J gene assigned</p></center>" >> $outputFile
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Productive mean</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N1</th><th>P2</th><th>DEL.D</th><th>D.DEL</th><th>P3</th><th>N2</th><th>P4</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELD DDEL P3 N2 P4 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELD</td><td>$DDEL</td><td>$P3</td><td>$N2</td><td>$P4</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>$median</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisProd_mean_wD.txt
	echo "</tbody></table>" >> $outputFile
	
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Unproductive mean</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N1</th><th>P2</th><th>DEL.D</th><th>D.DEL</th><th>P3</th><th>N2</th><th>P4</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELD DDEL P3 N2 P4 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELD</td><td>$DDEL</td><td>$P3</td><td>$N2</td><td>$P4</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>-</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisUnProd_mean_wD.txt
	echo "</tbody></table>" >> $outputFile
	
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Productive median</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N1</th><th>P2</th><th>DEL.D</th><th>D.DEL</th><th>P3</th><th>N2</th><th>P4</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELD DDEL P3 N2 P4 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELD</td><td>$DDEL</td><td>$P3</td><td>$N2</td><td>$P4</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>$median</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisProd_median_wD.txt
	echo "</tbody></table>" >> $outputFile
	
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Unproductive median</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N1</th><th>P2</th><th>DEL.D</th><th>D.DEL</th><th>P3</th><th>N2</th><th>P4</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELD DDEL P3 N2 P4 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELD</td><td>$DDEL</td><td>$P3</td><td>$N2</td><td>$P4</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>-</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisUnProd_median_wD.txt
	echo "</tbody></table>" >> $outputFile
	
	# again for no-d
	echo "<center><p style='font-size: 20;'>Unique rearrangements with only a V and J gene assigned</p></center>" >> $outputFile
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Productive mean</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N</th><th>P2</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>$median</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisProd_mean_nD.txt
	echo "</tbody></table>" >> $outputFile
	
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Unproductive mean</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N</th><th>P2</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>-</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisUnProd_mean_nD.txt
	echo "</tbody></table>" >> $outputFile
	
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Productive median</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N</th><th>P2</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>$median</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisProd_median_nD.txt
	echo "</tbody></table>" >> $outputFile
	
	echo "<table class='pure-table pure-table-striped' id='junction_table'> <caption>Unproductive median</caption><thead><tr><th>Donor</th><th>Number of sequences</th><th>V.DEL</th><th>P1</th><th>N</th><th>P2</th><th>DEL.J</th><th>Total.Del</th><th>Total.N</th><th>Total.P</th><th>CDR3.Length</th><thead></tr><tbody>" >> $outputFile
	while read Sample unique VDEL P1 N1 P2 DELJ TotalDel TotalN TotalP median
	do
		echo "<tr><td>$Sample</td><td>$unique</td><td>$VDEL</td><td>$P1</td><td>$N1</td><td>$P2</td><td>$DELJ</td><td>$TotalDel</td><td>$TotalN</td><td>$TotalP</td><td>-</td></tr>" >> $outputFile
	done < $outputDir/junctionAnalysisUnProd_median_nD.txt
	echo "</tbody></table>" >> $outputFile
	
	cat $dir/naive_junction.htm >> $outputFile
	
	echo "</div>" >> $outputFile
fi

echo "<div class='tabbertab' title='Downloads'>" >> $outputFile
echo "<table class='pure-table pure-table-striped'>" >> $outputFile
echo "<thead><tr><th>Description</th><th>Link</th></tr></thead>" >> $outputFile
echo "<tr><td>The filtered dataset</td><td><a href='allUnique.txt'>Download</a></td></tr>" >> $outputFile
echo "<tr><td colspan='2' style='background-color:#E0E0E0;'>Gene frequencies</td></tr>" >> $outputFile

echo "<tr><td>The dataset used to generate the distribution of V gene families graph</td><td><a href='VFFrequency.txt'>Download</a></td></tr>" >> $outputFile
if [[ "$useD" == "true" ]] ; then
	echo "<tr><td>The dataset used to generate  the distribution of D gene families graph</td><td><a href='DFFrequency.txt'>Download</a></td></tr>" >> $outputFile
fi

echo "<tr><td>The dataset used to generate the relative frequency of V gene usage graph</td><td><a href='VFrequency.txt'>Download</a></td></tr>" >> $outputFile
if [[ "$useD" == "true" ]] ; then
	echo "<tr><td>The dataset used to generate the relative frequency of D gene usage graph</td><td><a href='DFrequency.txt'>Download</a></td></tr>" >> $outputFile
fi
echo "<tr><td>The dataset used to generate the relative frequency of J gene usage graph</td><td><a href='JFrequency.txt'>Download</a></td></tr>" >> $outputFile
echo "<tr><td>The dataset used to generate the relative frequency of the D reading frame graph</td><td><a href='DReadingFrame.txt'>Download</a></td></tr>" >> $outputFile

echo "<tr><td colspan='2' style='background-color:#E0E0E0;'>CDR3 Characteristics</td></tr>" >> $outputFile
echo "<tr><td>The dataset used to generate the CDR3 length frequency graph</td><td><a href='CDR3LengthPlot.txt'>Download</a></td></tr>" >> $outputFile
echo "<tr><td>The dataset used to generate the Amino Acid Composition in the CDR3 graph</td><td><a href='AAComposition.txt'>Download</a></td></tr>" >> $outputFile

echo "<tr><td colspan='2' style='background-color:#E0E0E0;'>Heatmaps</td></tr>" >> $outputFile
for sample in $samples; do
	if [[ "$useD" == "true" ]] ; then
		echo "<tr><td>The data used to generate the VD heatmap for $sample.</td><td><a href='HeatmapVD_$sample.txt'>Download</a></td></tr>" >> $outputFile
	fi
	echo "<tr><td>The data used to generate the VJ heatmap for $sample.</td><td><a href='HeatmapVJ_$sample.txt'>Download</a></td></tr>" >> $outputFile
	if [[ "$useD" == "true" ]] ; then
		echo "<tr><td>The data used to generate the DJ heatmap for $sample.</td><td><a href='HeatmapDJ_$sample.txt'>Download</a></td></tr>" >> $outputFile
	fi
done

echo "<tr><td colspan='2' style='background-color:#E0E0E0;'>Circos</td></tr>" >> $outputFile
for sample in $samples; do
	if [[ "$useD" == "true" ]] ; then
		echo "<tr><td>The data used to generate the VD Circos plots for $sample.</td><td><a href='${sample}_VD_circos.txt'>Download</a></td></tr>" >> $outputFile
	fi
	echo "<tr><td>The data used to generate the VJ Circos plots for $sample.</td><td><a href='${sample}_VJ_circos.txt'>Download</a></td></tr>" >> $outputFile
	if [[ "$useD" == "true" ]] ; then
		echo "<tr><td>The data used to generate the DJ Circos plots for $sample.</td><td><a href='${sample}_DJ_circos.txt'>Download</a></td></tr>" >> $outputFile
	fi
done

#echo "<tr><td>A frequency count of V Gene + J Gene + CDR3</td><td><a href='VJCDR3_count.txt'>Download</a></td></tr>" >> $outputFile

echo "<tr><td colspan='2' style='background-color:#E0E0E0;'>Clonality</td></tr>" >> $outputFile
echo "<tr><td>The dataset used to calculate clonality score (Unique based on clonaltype, $clonalType)</td><td><a href='clonalityComplete.txt'>Download</a></td></tr>" >> $outputFile
# echo "<tr><td>Sequences that are present in more than one replicate</td><td><a href='clonaltypes_replicates.txt'>Download</a></td></tr>" >> $outputFile

echo "</table>" >> $outputFile

cat $dir/naive_downloads.htm >> $outputFile

echo "</div></html>" >> $outputFile
