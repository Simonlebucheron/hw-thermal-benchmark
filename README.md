# Hardware Thermal Benchmark Logger

Linux-only tools for thermal comparisons between hardware states.

`logger_rpm.sh` captures sensors to CSV, `scripts/benchmark.sh` starts capture and launches the workload, and `scripts/run_openbenchmark.sh` runs standard Phoronix Test Suite benchmarks.

## Requirements

```bash
sudo apt install lm-sensors gnuplot phoronix-test-suite
```

Check sensors before a run:

```bash
sensors
```

## Quick Start

Pick a label, then choose the flow you want:

```bash
./scripts/benchmark.sh commands cpu_hwstate1
```

Single terminal:

```bash
./scripts/benchmark.sh run cpu_hwstate1 cpu
```

Two terminals:

```bash
./scripts/benchmark.sh start cpu_hwstate1
```

```bash
./scripts/benchmark.sh load cpu
```

At capture start, the script asks for ambient temperature in `degC`; press Enter to skip. The `.meta` sidecar next to each CSV is generated only for run context.

Use `benchmark.config.json` for persistent defaults, `benchmark.config.example.json` as the model, `BENCH_CONFIG=/path/to/local.json` for local overrides, and environment variables such as `AMBIENT_TEMP_C` for temporary values.

## Command Reference

| Command | Args | What it does |
| --- | --- | --- |
| `commands` | `<label>` | Prints the exact capture and workload commands for the label and current default category. |
| `start` | `<label>` | Starts capture only. Use this in one terminal, then launch the workload in another. |
| `load` | `cpu`, `gpu`, `system` | Runs the OpenBenchmark workload only. If the category is omitted, the config default is used. |
| `run` | `<label>`[`cpu`,`gpu`,`system`] | Starts capture, waits for the pre-trigger window, runs the workload, then keeps capturing through the post-trigger window. |
| `doctor` | none | Shows the active config file, detected sensor chips, and effective defaults. |

If `openbenchmark.tests` is empty, category defaults are used. If you override the category on `load` or `run`, tests from the matching category are ignored unless `OPENBENCHMARK_TESTS_CSV` is set explicitly.

## Configuration

Official config file: [benchmark.config.json](benchmark.config.json)

Model file: [benchmark.config.example.json](benchmark.config.example.json)

All settings:

| Key | Type | Values | Default | Purpose |
| --- | --- | --- | --- | --- |
| `interval_s` | number | Positive number | `1` | Sampling interval in seconds. |
| `output_dir` | string | Local path | `data` | Directory for CSV captures and `.meta` sidecars. |
| `results_dir` | string | Local path | `results` | Directory for generated plots. |
| `mb_chip_pattern` | string | `auto` or a sensors chip name | `auto` | Motherboard sensor chip selection. |
| `gpu_chip_pattern` | string | `auto` or a sensors chip name | `auto` | GPU sensor chip selection. |
| `gpu_power_enabled` | boolean | `true`, `false` | `true` | Capture GPU power from `sensors` when available. |
| `trigger_pre_s` | integer | `0+` | `60` | Capture time before workload start in `run` mode. |
| `trigger_post_s` | integer | `0+` | `60` | Capture time after workload end in `run` mode. |
| `live_preview` | boolean | `true`, `false` | `true` | Print one-line real-time telemetry in terminal during capture. |
| `sensor_display_mode` | string | `off`, `inline`, `tmux` | `off` | Sensor display strategy in `run` mode (`tmux` opens a dedicated pane). |
| `openbenchmark.category` | string | `cpu`, `gpu`, `system` | `cpu` | Default OpenBenchmark category. |
| `openbenchmark.runs` | integer | Positive number | `3` | Number of benchmark repetitions. |
| `openbenchmark.tests` | array of strings | Empty or a list of test names | built-in defaults | Explicit test list for the default category; `pts/` prefixes are optional. |

To use a local config without editing the tracked file, point `BENCH_CONFIG` to your own JSON file:

```bash
BENCH_CONFIG=$HOME/.config/hw-thermal-benchmark/config.json ./scripts/benchmark.sh run cpu_hwstate1 cpu
```

## Plots

CSV files are written to `data/` by default. Plotting a CSV without `out=` names the result from the input file:

```bash
gnuplot -e "file='data/cpu_hwstate1_20260723_195045.csv'" gnuplot/temperature.gnuplot
gnuplot -e "file='data/cpu_hwstate1_20260723_195045.csv'" gnuplot/fan.gnuplot
```

Example outputs:

- `results/cpu_hwstate1_20260723_195045_temperature.png`
- `results/cpu_hwstate1_20260723_195045_fan.png`

The GPU, CPU, and platform power traces are drawn on the secondary axis. Use `sensor_display_mode=off` for clean OpenBenchmark logs in `run` mode, or `tmux` if you want a live telemetry pane. Pass `out=` explicitly for a custom destination.

## Method

1. Capture an idle baseline with `./scripts/benchmark.sh run idle_hwstate1 system`.
2. Capture CPU and GPU scenarios with the same ambient conditions, BIOS fan curves, workload category, run count, and sampling interval.
3. Plot matching labels and compare peak, plateau, and cool-down behavior.

## Validation

```bash
bash -n logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
shellcheck logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
```
