# rktop

`rktop` is a small Rust monitor for Rockchip RK3588 systems running a mainline
Linux kernel. It samples CPU usage, memory/swap usage, CPU/GPU temperatures,
GPU frequency, and Panthor GPU utilization when mainline DRM fdinfo profiling
counters are enabled.

The monitor itself does not require root privileges. If Panthor profiling is
missing or below the level needed for GPU usage, `rktop` asks whether it should
run a one-shot `sudo` write to enable profiling. If you decline or enabling
fails, GPU usage is shown as `n/a`.

## Run

```sh
cargo run --release
```

Useful options:

```sh
cargo run -- --once
cargo run -- --interval-ms 500
cargo run -- --no-clear
```

## Data Sources

- CPU usage: `/proc/stat`
- Memory/swap usage: `/proc/meminfo`
- CPU frequencies: `/sys/devices/system/cpu/cpu*/cpufreq/scaling_{cur,max}_freq`
- Temperatures: `/sys/class/thermal/thermal_zone*/`
- GPU frequency: `/sys/class/devfreq/*gpu*/{cur,max}_freq`
- GPU usage: Panthor DRM fdinfo counters under `/proc/<pid>/fdinfo/<fd>`
- Panthor profiling state:
  `/sys/bus/platform/drivers/panthor/<gpu>/profiling`

Mainline Panthor disables engine/cycle profiling by default for power-saving
reasons. `rktop` requires profiling level `2` or higher for GPU usage.

## NPU TODO

RK3588 NPU frequency and usage are intentionally not sampled yet. The mainline
Rocket NPU driver currently exposes `/dev/accel/accel0` and runtime PM state for
the NPU platform devices, but it does not expose a stable devfreq or DRM
fdinfo usage interface. Add NPU frequency/usage once the mainline driver grows
that ABI.
