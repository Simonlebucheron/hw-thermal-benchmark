# Benchmark Checklist

Use this list for both BEFORE and AFTER runs.

## Environment

- [ ] Ambient temperature recorded (degC): ______
- [ ] Same room and airflow conditions
- [ ] Same case panel state (open or closed)
- [ ] Same BIOS and fan curve profile
- [ ] No large background jobs or updates running

## Logger Setup

- [ ] `sensors` output verified before run
- [ ] Same logger script used for both runs (`logger_rpm.sh`)
- [ ] Same sampling interval (`INTERVAL`)
- [ ] Output filename includes scenario and hardware state

## Idle Scenario

- [ ] 10 to 15 min system settle before recording
- [ ] 15+ min idle logging collected

## Load Scenario

- [ ] Same OpenBenchmark category or explicit tests used (cpu, gpu, or system)
- [ ] Same run count for benchmark tool
- [ ] Logger started before workload launch

## Post-Run

- [ ] CSV file exists and has stable header
- [ ] No malformed rows (column count is constant)
- [ ] Temperature and fan plots generated
- [ ] Notes added for anomalies (throttling, fan spikes, app crash)
