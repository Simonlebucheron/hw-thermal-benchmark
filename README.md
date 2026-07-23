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

Then use two terminals:

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
| `openbenchmark.category` | string | `cpu`, `gpu`, `system` | `cpu` | Default OpenBenchmark category. |
| `openbenchmark.runs` | integer | Positive number | `3` | Number of benchmark repetitions. |
| `openbenchmark.tests` | array of strings | Empty or a list of test names | built-in defaults | Explicit test list; `pts/` prefixes are optional. |

If `openbenchmark.tests` is empty, the script uses category defaults:

- cpu: `build-linux-kernel`, `compress-zstd`
- gpu: `glmark2`, `unigine-heaven`
- system: `build-linux-kernel`, `openssl`

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

The GPU power trace is drawn on the secondary axis in both plots when `gpu_power_enabled` is `true`.

If you want a custom destination, pass `out=` explicitly.

## Notes

- Use labels that describe the hardware state, such as `cpu_hwstate1` or `gpu_hwstate2`.
- Keep BIOS fan curves identical between runs.
- Keep ambient room temperature as close as possible.
- Keep case panel state identical.
- Keep workload category or explicit test list identical.
- Keep benchmark run count identical.
- Keep sampling interval identical.

## Validation

```bash
bash -n logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
shellcheck logger_rpm.sh logger_pwm.sh scripts/run_openbenchmark.sh scripts/benchmark.sh
```
