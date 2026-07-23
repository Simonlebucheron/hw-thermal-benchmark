# Hardware Thermal Benchmark Logger

Simple temperature and fan monitoring tools based on `lm-sensors`.

## Requirements

Install dependencies:

```bash
sudo apt install lm-sensors gnuplot
```

## Check sensors:
```
sensors
```
---
## Recording data

Create data directory:
```
mkdir -p data
```
Start a recording:
```
./logger_rpm.sh data/test_name.csv
```
Example:
```
./logger_rpm.sh data/stock_idle.csv
./logger_rpm.sh data/stock_stress.csv
```
Stop recording:
```
Ctrl+C
```
Sampling interval:
```
1 second
```

---

## Plot temperature data

Interactive plot:
```
gnuplot -p \
-e "file='data/stock_stress.csv'" \
gnuplot/temperature.gnuplot
```
Generate PNG:
```
gnuplot \
-e "file='data/stock_stress.csv';out='results/stock_stress_temperature.png'" \
gnuplot/temperature.gnuplot
```

---

## Plot fan data

Interactive plot:
```
gnuplot -p \
-e "file='data/stock_stress.csv'" \
plts/fan.gnuplot
```
Generate PNG:
```
gnuplot \
-e "file='data/stock_stress.csv';out='results/stock_stress_fan.png'" \
gnuplot/fan.gnuplot
```

---

## CSV format

Example:
```
time_s
timestamp
cpu_temp_c
mb_temp_c
gpu_edge_c
gpu_junction_c
gpu_mem_c
gpu_power_w
cpu_fan_rpm
case_fan1_rpm
case_fan2_rpm
gpu_fan_rpm
Test methodology
```
## Recommended scenarios:

- Idle test
- Gaming workload
- CPU stress test
- GPU stress test

Keep the workload identical when comparing hardware changes.
