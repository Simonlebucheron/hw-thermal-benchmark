# Hardware Thermal Benchmark Logger

Small Linux thermal benchmark tools for repeatable before/after hardware comparisons.

The core logger is `logger_rpm.sh`.
`logger_pwm.sh` is kept as a compatibility entrypoint and forwards to `logger_rpm.sh`.

For ergonomic execution, use `scripts/benchmark.sh` as the single control entrypoint.

## 1) Requirements

Mandatory:

```bash
sudo apt install lm-sensors gnuplot
```

Optional workload tools:

```bash
sudo apt install phoronix-test-suite
```

Quick check:

```bash
sensors
```

## 2) Fast Ergonomic Workflow (2 terminals)

Print ready-to-run commands for a session label:

```bash
./scripts/benchmark.sh commands before_stress
```

Then run:

- Terminal A (capture):

```bash
./scripts/benchmark.sh start before_stress
```

- Terminal B (run workload):

```bash
./scripts/benchmark.sh load cpu
```

This gives exactly one command for capture and one command for load execution.

## 3) Record Data (manual mode)

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

## 4) JSON Configuration

Default config file:

```text
benchmark.config.json
```

Example keys:

- `interval_s`
- `output_dir`
- `mb_chip_pattern`
- `gpu_chip_pattern`
- `openbenchmark.category`
- `openbenchmark.runs`
- `openbenchmark.tests`

Quick diagnostics:

```bash
./scripts/benchmark.sh doctor
```

The `start` command auto-detects motherboard and GPU chip patterns from `sensors` when set to `auto`.

## 5) CSV Format

Header (stable order):

```text
time_s,timestamp,cpu_temp_c,mb_temp_c,gpu_edge_c,gpu_junction_c,gpu_mem_c,gpu_power_w,cpu_fan_rpm,case_fan1_rpm,case_fan2_rpm,gpu_fan_rpm
```

Missing sensor values are written as `NaN` to keep column alignment safe for plotting and post-processing.

## 6) Plot Data

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

## 7) Workload Scenarios

### Idle baseline

1. Let system settle for 10 to 15 minutes at desktop idle.
2. Start logger.
3. Record at least 15 minutes.

### OpenBenchmark categories

```bash
chmod +x scripts/run_openbenchmark.sh
./scripts/benchmark.sh load cpu
./scripts/benchmark.sh load gpu
./scripts/benchmark.sh load system
```

Default tests are popular PTS profiles per category:

- cpu: `build-linux-kernel`, `compress-zstd`
- gpu: `glmark2`, `unigine-heaven`
- system: `build-linux-kernel`, `openssl`

You can force explicit tests in `benchmark.config.json`:

```json
{
  "openbenchmark": {
    "category": "cpu",
    "runs": 3,
    "tests": ["build-linux-kernel"]
  }
}
```

When `openbenchmark.tests` is set, it overrides category defaults.
The script runs:

```bash
phoronix-test-suite benchmark <tests...>
```

## 8) Repeatability Rules (Before/After)

- Keep BIOS fan curves identical between runs.
- Keep ambient room temperature as close as possible.
- Keep case panel state identical (open/closed).
- Keep workload category or explicit test list identical.
- Keep benchmark run count identical.
- Keep sampling interval identical.
- Record notes for any deviation.

Use [BENCHMARK_CHECKLIST.md](BENCHMARK_CHECKLIST.md) during execution.

## 9) Lightweight Validation

Run quick checks before collecting final comparison data:

```bash
bash -n logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh
bash -n scripts/benchmark.sh
shellcheck logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
gnuplot -e "file='data/stock_stress.csv';out='results/smoke_temp.png'" gnuplot/temperature.gnuplot
gnuplot -e "file='data/stock_stress.csv';out='results/smoke_fan.png'" gnuplot/fan.gnuplot
```
