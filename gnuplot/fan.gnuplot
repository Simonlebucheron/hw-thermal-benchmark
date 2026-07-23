if (!exists("file")) file="benchmark.csv"
if (!exists("out")) out=sprintf("results/%s_fan.png", system(sprintf("basename %s .csv", file)))

file_base = system(sprintf("basename '%s' .csv", file))
ambient_temp = system(sprintf("sed -n 's/^ambient_temp_c=//p' 'data/%s.meta' 2>/dev/null | head -n 1", file_base))


set datafile separator ","

set terminal pngcairo size 1600,900 enhanced
set output out


if (strlen(ambient_temp) > 0) ambient_temp_value = ambient_temp + 0.0
if (strlen(ambient_temp) > 0) set arrow 1 from graph 0, first ambient_temp_value to graph 1, first ambient_temp_value nohead dt 2 lw 2 lc rgb "#666666"


set title sprintf("Fan Speed - %s", file)

if (strlen(ambient_temp) > 0) set title sprintf("Fan Speed - %s (ambient %.1f°C)", file, ambient_temp_value)

set xlabel "Time (s)"
set ylabel "RPM"
set y2label "Power (W)"
set y2tics
set ytics nomirror

set grid
set key outside


plot \
file every ::1 using 1:9 with lines lw 2 title "CPU fan", \
file every ::1 using 1:10 with lines lw 2 title "Case fan 1", \
file every ::1 using 1:11 with lines lw 2 title "Case fan 2", \
file every ::1 using 1:12 with lines lw 2 title "GPU fan", \
file every ::1 using 1:8 axes x1y2 with lines lw 2 lc rgb "#d1495b" title "GPU Power"


unset output
