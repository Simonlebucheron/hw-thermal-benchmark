if (!exists("file")) file="benchmark.csv"
if (!exists("out")) out="fan.png"


set datafile separator ","

set terminal pngcairo size 1600,900 enhanced
set output out


set title sprintf("Ventilateurs - %s", file)

set xlabel "Temps (s)"
set ylabel "RPM"

set grid
set key outside


plot \
file using 1:9 with lines lw 2 title "CPU fan", \
file using 1:10 with lines lw 2 title "Case fan 1", \
file using 1:11 with lines lw 2 title "Case fan 2", \
file using 1:12 with lines lw 2 title "GPU fan"


unset output
