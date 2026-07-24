# Hardware Thermal Benchmark Logger

Linux-only tools for thermal comparisons between hardware states.

`logger_rpm.sh` captures sensors to CSV, `scripts/benchmark.sh` starts capture and launches the workload, and `scripts/run_openbenchmark.sh` executes the resolved Phoronix Test Suite benchmark list.

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
| `commands` | `<label>` | Prints the exact capture and workload commands for the label and current `openbenchmark.default_category`. |
| `start` | `<label>` | Starts capture only. Use this in one terminal, then launch the workload in another. |
| `load` | `cpu`, `gpu`, `system` | Runs the OpenBenchmark workload only. If the category is omitted, `openbenchmark.default_category` is used. |
| `run` | `<label>`[`cpu`,`gpu`,`system`] | Starts capture, waits for the pre-trigger window, runs the workload, then keeps capturing through the post-trigger window. If the category is omitted, `openbenchmark.default_category` is used. |
| `doctor` | none | Shows the active config file, detected sensor chips, and effective defaults. |

`openbenchmark.tests` is best kept as an object keyed by category so CPU and GPU workloads can be chosen independently. If you want a one-off override, set `OPENBENCHMARK_TESTS_CSV` for that run.

## Configuration

Official config file: [benchmark.config.json](benchmark.config.json)

Model file: [benchmark.config.example.json](benchmark.config.example.json)

All settings:

| Key | Type | Values | Default | Purpose |
| --- | --- | --- | --- | --- |
| `interval_s` | number | Positive number | `1` | Sampling interval in seconds. |
| `output_dir` | string | Local path | `data` | Directory for CSV captures and `.meta` sidecars. |
| `results_dir` | string | Local path | `results` | Directory for generated plots. |
| `mb_chip_pattern` | string | `auto` or a sensors chip name, e.g. `"nct6791-isa-0290"` | `auto` | Motherboard sensor chip selection. |
| `gpu_chip_pattern` | string | `auto` or a sensors chip name, e.g. `"amdgpu-pci-0300"` | `auto` | GPU sensor chip selection. |
| `gpu_power_enabled` | boolean | `true`, `false` | `true` | Capture GPU power from `sensors` when available. |
| `trigger_pre_s` | integer | `0+` | `60` | Capture time before workload start in `run` mode. |
| `trigger_post_s` | integer | `0+` | `60` | Capture time after workload end in `run` mode. |
| `live_preview` | boolean | `true`, `false` | `true` | Print one-line real-time telemetry in terminal during capture. |
| `sensor_display_mode` | string | `off`, `inline`, `tmux` | `off` | Sensor display strategy in `run` mode (`tmux` opens a dedicated pane). |
| `openbenchmark.default_category` | string | `cpu`, `gpu`, `system` | `cpu` | Default OpenBenchmark category used when `load`/`run` category arg is omitted. |
| `openbenchmark.runs` | integer | Positive number | `3` | Number of benchmark repetitions. |
| `openbenchmark.tests` | object | Category keys with arrays of test names | example CPU/GPU/system sets | Explicit test lists per category; `pts/` prefixes are optional. |

See [benchmark.config.example.json](benchmark.config.example.json) for a complete example of the nested `openbenchmark.tests` shape.

`openbenchmark.category` is still accepted for backward compatibility, but `openbenchmark.default_category` is preferred.

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
2. Capture CPU and GPU scenarios with the same ambient conditions, BIOS fan curves, workload category, benchmark set, run count, and sampling interval.
3. Plot matching labels and compare peak, plateau, and cool-down behavior.

## Validation

```bash
bash -n logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
shellcheck logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
```
