# Hardware Thermal Benchmark Logger

Small Linux thermal benchmark tools for repeatable before/after hardware comparisons.

The core logger is `logger_rpm.sh`.
`logger_pwm.sh` is kept as a compatibility entrypoint and forwards to `logger_rpm.sh`.

## 1) Requirements

Mandatory:

```bash
sudo apt install lm-sensors gnuplot
```

Optional workload tools:

```bash
sudo apt install stress-ng phoronix-test-suite
```

Quick check:

```bash
sensors
```

## 2) Record Data

Create output folder:

```bash
mkdir -p data results
```

Start logging (default interval: 1 second):

```bash
./logger_rpm.sh data/stock_idle.csv
```

Change sampling interval (seconds):

```bash
INTERVAL=2 ./logger_rpm.sh data/stock_idle_2s.csv
```

Stop logging with Ctrl+C.

### Sensor Label Overrides

If your chip names differ, override patterns without editing scripts:

```bash
MB_CHIP_PATTERN='it8688-isa-0a30' \
GPU_CHIP_PATTERN='amdgpu-pci-0300' \
./logger_rpm.sh data/custom.csv
```

## 3) CSV Format

Header (stable order):

```text
time_s,timestamp,cpu_temp_c,mb_temp_c,gpu_edge_c,gpu_junction_c,gpu_mem_c,gpu_power_w,cpu_fan_rpm,case_fan1_rpm,case_fan2_rpm,gpu_fan_rpm
```

Missing sensor values are written as `NaN` to keep column alignment safe for plotting and post-processing.

## 4) Plot Data

Temperature plot (interactive):

```bash
gnuplot -p \
-e "file='data/stock_stress.csv'" \
gnuplot/temperature.gnuplot
```

Temperature plot (PNG):

```bash
gnuplot \
-e "file='data/stock_stress.csv';out='results/stock_stress_temperature.png'" \
gnuplot/temperature.gnuplot
```

Fan plot (interactive):

```bash
gnuplot -p \
-e "file='data/stock_stress.csv'" \
gnuplot/fan.gnuplot
```

Fan plot (PNG):

```bash
gnuplot \
-e "file='data/stock_stress.csv';out='results/stock_stress_fan.png'" \
gnuplot/fan.gnuplot
```

## 5) Workload Scenarios

### Idle baseline

1. Let system settle for 10 to 15 minutes at desktop idle.
2. Start logger.
3. Record at least 15 minutes.

### Stress-ng (simple local stress)

```bash
chmod +x scripts/run_stress_ng.sh
./scripts/run_stress_ng.sh 900
```

### OpenBenchmark scenarios

```bash
chmod +x scripts/run_openbenchmark.sh
./scripts/run_openbenchmark.sh cpu
./scripts/run_openbenchmark.sh gpu
./scripts/run_openbenchmark.sh mixed
```

The script uses `phoronix-test-suite batch-run` and defaults to 3 runs per test.
Override with `FORCE_TIMES_TO_RUN=<n>`.

## 6) Repeatability Rules (Before/After)

- Keep BIOS fan curves identical between runs.
- Keep ambient room temperature as close as possible.
- Keep case panel state identical (open/closed).
- Keep workload and duration identical.
- Keep sampling interval identical.
- Record notes for any deviation.

Use [BENCHMARK_CHECKLIST.md](BENCHMARK_CHECKLIST.md) during execution.

## 7) Lightweight Validation

Run quick checks before collecting final comparison data:

```bash
bash -n logger_rpm.sh logger_pwm.sh scripts/run_stress_ng.sh scripts/run_openbenchmark.sh
shellcheck logger_rpm.sh logger_pwm.sh scripts/run_stress_ng.sh scripts/run_openbenchmark.sh
gnuplot -e "file='data/stock_stress.csv';out='results/smoke_temp.png'" gnuplot/temperature.gnuplot
gnuplot -e "file='data/stock_stress.csv';out='results/smoke_fan.png'" gnuplot/fan.gnuplot
```
