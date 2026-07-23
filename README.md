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

## Configuration

Default config file: [benchmark.config.json](benchmark.config.json)

Keys used by the simplified workflow:

- `interval_s`
- `output_dir`
- `mb_chip_pattern`
- `gpu_chip_pattern`
- `openbenchmark.category`
- `openbenchmark.runs`
- `openbenchmark.tests`

Example:

```json
{
  "interval_s": 1,
  "output_dir": "data",
  "results_dir": "results",
  "mb_chip_pattern": "auto",
  "gpu_chip_pattern": "auto",
  "openbenchmark": {
    "category": "cpu",
    "runs": 3,
    "tests": ["build-linux-kernel"]
  }
}
```

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
