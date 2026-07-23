# Usage:
# gnuplot -p -e "file='data/stock_stress.csv';out='results/stock_stress_temp.png'" gnuplot/temperature.gnuplot


if (!exists("file")) file="benchmark.csv"
if (!exists("out")) out="temperature.png"


set datafile separator ","

set terminal pngcairo size 1600,900 enhanced
set output out


set title sprintf("Temperatures - %s", file)

set xlabel "Time (s)"
set ylabel "Temperature (°C)"

set grid
set key outside


plot \
file every ::1 using 1:3 with lines lw 2 title "CPU", \
file every ::1 using 1:4 with lines lw 2 title "Motherboard", \
file every ::1 using 1:5 with lines lw 2 title "GPU Edge", \
file every ::1 using 1:6 with lines lw 2 title "GPU Junction", \
file every ::1 using 1:7 with lines lw 2 title "GPU Memory"


unset output
