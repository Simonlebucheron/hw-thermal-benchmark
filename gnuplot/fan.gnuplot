# Render the fan speed and power plot from a benchmark CSV.
# Usage:
# gnuplot -p -e "file='data/stock_stress.csv';out='results/stock_stress_fan.png'" gnuplot/fan.gnuplot

if (!exists("file")) file="benchmark.csv"
if (!exists("out")) out=sprintf("results/%s_fan.png", system(sprintf("basename '%s' .csv", file)))

file_base = system(sprintf("basename '%s' .csv", file))
file_dir = system(sprintf("dirname '%s'", file))
meta_file = sprintf("%s/%s.meta", file_dir, file_base)
ambient_temp = system(sprintf("sed -n 's/^ambient_temp_c=//p' '%s' 2>/dev/null | head -n 1", meta_file))


set datafile separator ","

set terminal pngcairo size 1600,900 noenhanced
set output out


if (strlen(ambient_temp) > 0) ambient_temp_value = ambient_temp + 0.0
if (strlen(ambient_temp) > 0) set arrow 1 from graph 0, first ambient_temp_value to graph 1, first ambient_temp_value nohead dt 2 lw 2 lc rgb "#666666"


set title sprintf("Fan Speed - %s", file_base)

if (strlen(ambient_temp) > 0) set title sprintf("Fan Speed - %s (ambient %.1f°C)", file_base, ambient_temp_value)

set xlabel "Time (s)"
set ylabel "RPM"
set y2label "Power (W)"
set y2tics
set ytics nomirror

set grid
set key outside

axis_stats = system(sprintf("awk -F, 'NR>1 {for (i=9; i<=12; i++) {if ($i ~ /^-?[0-9]+([.][0-9]+)?$/) {v=$i+0; if (!yset || v<ymin) ymin=v; if (!yset || v>ymax) ymax=v; yset=1}} for (i=1; i<=3; i++) {col=(i==1?8:(i==2?13:14)); val=$col; if (val ~ /^-?[0-9]+([.][0-9]+)?$/) {p=val+0; if (!pset || p<y2min) y2min=p; if (!pset || p>y2max) y2max=p; pset=1}}} END {if (!yset) {ymin=0; ymax=1000}; if (!pset) {y2min=0; y2max=100}; printf \"%%.6f %%.6f %%.6f %%.6f\", ymin, ymax, y2min, y2max}' '%s'", file))
y_min = real(word(axis_stats, 1))
y_max = real(word(axis_stats, 2))
y2_min = real(word(axis_stats, 3))
y2_max = real(word(axis_stats, 4))

if (y_min >= y_max) {
	y_min = 0
	y_max = 1000
}
if (y2_min >= y2_max) {
	y2_min = 0
	y2_max = 100
}

y_pad = (y_max - y_min) * 0.05
y2_pad = (y2_max - y2_min) * 0.05
if (y_pad <= 0) y_pad = 50
if (y2_pad <= 0) y2_pad = 1

set yrange [y_min - y_pad:y_max + y_pad]
set y2range [y2_min - y2_pad:y2_max + y2_pad]


plot \
file every ::1 using 1:9 with lines lw 2 title "CPU fan", \
file every ::1 using 1:10 with lines lw 2 title "Case fan 1", \
file every ::1 using 1:11 with lines lw 2 title "Case fan 2", \
file every ::1 using 1:12 with lines lw 2 title "GPU fan", \
file every ::1 using 1:8 axes x1y2 with lines lw 2 lc rgb "#d1495b" title "GPU Power", \
file every ::1 using 1:13 axes x1y2 with lines lw 2 lc rgb "#3b82f6" title "CPU Power", \
file every ::1 using 1:14 axes x1y2 with lines lw 2 lc rgb "#1f7a1f" title "Platform Power"


unset output
