# Usage :
# gnuplot -p -e "file='data/stock_stress.csv';out='results/stock_stress_temp.png'" temperature.gnuplot


if (!exists("file")) file="benchmark.csv"
if (!exists("out")) out="temperature.png"


set datafile separator ","

set terminal pngcairo size 1600,900 enhanced
set output out


set title sprintf("Temperature - %s", file)

set xlabel "Temps (s)"
set ylabel "Temperature (°C)"

set grid
set key outside


plot \
file using 1:3 with lines lw 2 title "CPU", \
file using 1:4 with lines lw 2 title "Carte mère", \
file using 1:5 with lines lw 2 title "GPU Edge", \
file using 1:6 with lines lw 2 title "GPU Junction", \
file using 1:7 with lines lw 2 title "GPU Memory"


unset output
