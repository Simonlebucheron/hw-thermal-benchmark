# Usage:
# gnuplot -p -e "file='data/stock_stress.csv';out='results/stock_stress_temp.png'" gnuplot/temperature.gnuplot


if (!exists("file")) file="benchmark.csv"
if (!exists("out")) out=sprintf("results/%s_temperature.png", system(sprintf("basename %s .csv", file)))

file_base = system(sprintf("basename '%s' .csv", file))
ambient_temp = system(sprintf("sed -n 's/^ambient_temp_c=//p' 'data/%s.meta' 2>/dev/null | head -n 1", file_base))


set datafile separator ","

set terminal pngcairo size 1600,900 enhanced
set output out


if (strlen(ambient_temp) > 0) ambient_temp_value = ambient_temp + 0.0
if (strlen(ambient_temp) > 0) set arrow 1 from graph 0, first ambient_temp_value to graph 1, first ambient_temp_value nohead dt 2 lw 2 lc rgb "#666666"


set title sprintf("Temperatures - %s", file)

if (strlen(ambient_temp) > 0) set title sprintf("Temperatures - %s (ambient %.1f°C)", file, ambient_temp_value)

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
