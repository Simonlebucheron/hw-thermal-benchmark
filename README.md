# Hardware Thermal Benchmark Logger

Linux-only tools for simple thermal comparisons between hardware states.

The workflow is intentionally small:

- `logger_rpm.sh` captures sensors to CSV
- `scripts/benchmark.sh` starts capture and launches the workload
- `scripts/run_openbenchmark.sh` runs standard Phoronix Test Suite benchmarks

## Requirements

```bash
sudo apt install lm-sensors gnuplot phoronix-test-suite
```

Check sensors before a run:

```bash
sensors
```

## Quick Start

Pick a label that describes the hardware state:

```bash
./scripts/benchmark.sh commands cpu_hwstate1
```

Fastest path (single terminal, fully automated trigger windows):

```bash
./scripts/benchmark.sh run cpu_hwstate1 cpu
```

Two-terminal mode (manual workload start):

```bash
./scripts/benchmark.sh start cpu_hwstate1
```

```bash
./scripts/benchmark.sh load cpu
```

At the start of capture, the script asks for an ambient temperature in `degC`. Press Enter to skip and continue.
A small `.meta` file is written next to the CSV with the label, timestamp, and ambient temperature if provided.
It is a generated sidecar, ignored by git, and not consumed by the plotting or benchmark scripts.
GPU power capture is enabled by default through `benchmark.config.json` and is plotted on a secondary axis.
CPU package power is sampled from Linux powercap/RAPL when available and plotted on a secondary axis too.
`platform_power_w` is a practical combined trace (`cpu_power_w + gpu_power_w` when both are available).

Recommended split:

- Keep `benchmark.config.json` for persistent project defaults.
- Keep `.meta` as run-sidecar context only.
- Use environment variables for temporary overrides (`BENCH_CONFIG`, `AMBIENT_TEMP_C`, etc.).

## Configuration

Default config file: [benchmark.config.json](benchmark.config.json)

Summary:

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

If `openbenchmark.tests` is empty, the script uses category defaults:

- cpu: `build-linux-kernel`, `compress-zstd`
- gpu: `glmark2`, `unigine-heaven`
- system: `build-linux-kernel`, `openssl`

Important: if you run `./scripts/benchmark.sh load gpu` (or `run ... gpu`) while `openbenchmark.category` is `cpu`, the script now ignores configured CPU test overrides and uses GPU defaults unless `OPENBENCHMARK_TESTS_CSV` is explicitly set.

## Outputs

CSV files are written to `data/` by default.

Plot the CSV without specifying an output name and the script will create a file linked to the input name:

```bash
gnuplot -e "file='data/cpu_hwstate1_20260723_195045.csv'" gnuplot/temperature.gnuplot
gnuplot -e "file='data/cpu_hwstate1_20260723_195045.csv'" gnuplot/fan.gnuplot
```

That produces files such as:

- `results/cpu_hwstate1_20260723_195045_temperature.png`
- `results/cpu_hwstate1_20260723_195045_fan.png`

The GPU, CPU, and platform power traces are drawn on the secondary axis in both plots.

For clean OpenBenchmark logs in `run` mode, use `sensor_display_mode=off` (or `tmux` if you want a dedicated live telemetry pane).

If you want a custom destination, pass `out=` explicitly.

## Notes

- Use labels that describe the hardware state, such as `cpu_hwstate1` or `gpu_hwstate2`.
- Keep BIOS fan curves identical between runs.
- Keep ambient room temperature as close as possible.
- Keep case panel state identical.
- Keep workload category or explicit test list identical.
- Keep benchmark run count identical.
- Keep sampling interval identical.

## Benchmark Method

1. Idle baseline: run `./scripts/benchmark.sh run idle_hwstate1 system` without foreground workload changes.
2. CPU scenario: run `./scripts/benchmark.sh run cpu_hwstate1 cpu`.
3. GPU scenario: run `./scripts/benchmark.sh run gpu_hwstate1 gpu`.
4. Repeat each scenario with the same ambient and BIOS settings.
5. Generate plots from matching labels and compare peak, plateau, and cool-down slopes.

## Validation

```bash
bash -n logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
shellcheck logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
```
