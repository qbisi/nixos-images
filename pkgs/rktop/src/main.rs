use std::env;
use std::io::{self, Write};
use std::path::Path;
use std::process::{Command, ExitCode};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use rktop::{
    CpuCore, GpuSnapshot, MemoryUsage, PanthorProfilingState, Snapshot, collect_snapshot,
    read_cpu_sample, read_gpu_sample, read_panthor_profiling_state,
};

const LABEL_WIDTH: usize = 4;
const FREQUENCY_WIDTH: usize = 12;
const CAPACITY_WIDTH: usize = 12;
const TEMPERATURE_WIDTH: usize = 5;
const USAGE_WIDTH: usize = 6;

#[derive(Debug, Clone)]
struct Config {
    interval: Duration,
    once: bool,
    clear_screen: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            interval: Duration::from_secs(1),
            once: false,
            clear_screen: true,
        }
    }
}

fn main() -> ExitCode {
    let config = match parse_args(env::args().skip(1)) {
        Ok(config) => config,
        Err(message) => {
            eprintln!("{message}");
            eprintln!();
            print_help();
            return ExitCode::from(2);
        }
    };

    if let Err(error) = run(config) {
        eprintln!("rktop: {error}");
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}

fn run(config: Config) -> io::Result<()> {
    maybe_enable_panthor_profiling()?;

    let mut previous_cpu = read_cpu_sample()?;
    let mut previous_gpu = read_gpu_sample();
    let mut stdout = io::stdout();

    loop {
        thread::sleep(config.interval);

        let current_cpu = read_cpu_sample()?;
        let current_gpu = read_gpu_sample();
        let snapshot = collect_snapshot(&previous_cpu, &current_cpu, &previous_gpu, &current_gpu);

        if config.clear_screen {
            write!(stdout, "\x1b[2J\x1b[H")?;
        }

        render(&mut stdout, &snapshot, config.interval)?;
        stdout.flush()?;

        if config.once {
            break;
        }

        previous_cpu = current_cpu;
        previous_gpu = current_gpu;
    }

    Ok(())
}

fn maybe_enable_panthor_profiling() -> io::Result<()> {
    let state = read_panthor_profiling_state();
    if state.as_ref().is_some_and(|state| state.value >= 2) {
        return Ok(());
    }

    match &state {
        Some(state) => eprintln!(
            "Panthor profiling is {} at {}; GPU usage needs >= 2.",
            state.value,
            state.path.display()
        ),
        None => eprintln!("Panthor profiling sysfs node was not found; GPU usage is unavailable."),
    }

    if !prompt_yes_no("Enable Panthor profiling with sudo now? [y/N] ")? {
        eprintln!("Continuing with GPU usage n/a.");
        return Ok(());
    }

    let status = match enable_panthor_profiling_with_sudo(state.as_ref()) {
        Ok(status) => status,
        Err(error) => {
            eprintln!(
                "Unable to run sudo to enable Panthor profiling: {error}; continuing with GPU usage n/a."
            );
            return Ok(());
        }
    };
    if !status.success() {
        eprintln!("Unable to enable Panthor profiling; continuing with GPU usage n/a.");
        return Ok(());
    }

    match read_panthor_profiling_state() {
        Some(state) if state.value >= 2 => eprintln!(
            "Panthor profiling enabled: {} = {}.",
            state.path.display(),
            state.value
        ),
        Some(state) => eprintln!(
            "Panthor profiling is still {} at {}; continuing with GPU usage n/a.",
            state.value,
            state.path.display()
        ),
        None => eprintln!(
            "Panthor profiling sysfs node is still missing; continuing with GPU usage n/a."
        ),
    }

    Ok(())
}

fn prompt_yes_no(prompt: &str) -> io::Result<bool> {
    eprint!("{prompt}");
    io::stderr().flush()?;

    let mut answer = String::new();
    if io::stdin().read_line(&mut answer)? == 0 {
        eprintln!();
        return Ok(false);
    }

    Ok(matches!(answer.trim(), "y" | "Y" | "yes" | "YES"))
}

fn enable_panthor_profiling_with_sudo(
    state: Option<&PanthorProfilingState>,
) -> io::Result<std::process::ExitStatus> {
    if let Some(state) = state {
        return write_existing_panthor_profiling_node(&state.path);
    }

    Command::new("sudo")
        .arg("sh")
        .arg("-c")
        .arg(
            "for p in /sys/bus/platform/drivers/panthor/*/profiling /sys/devices/platform/fb000000.gpu/profiling; do \
             [ -e \"$p\" ] || continue; printf 2 > \"$p\" && exit 0; done; \
             echo 'panthor profiling node not found' >&2; exit 1",
        )
        .status()
}

fn write_existing_panthor_profiling_node(path: &Path) -> io::Result<std::process::ExitStatus> {
    Command::new("sudo")
        .arg("sh")
        .arg("-c")
        .arg("printf 2 > \"$1\"")
        .arg("sh")
        .arg(path)
        .status()
}

fn render(mut out: impl Write, snapshot: &Snapshot, interval: Duration) -> io::Result<()> {
    writeln!(
        out,
        "{} {} - mainline RK3588 monitor",
        env!("CARGO_PKG_NAME"),
        env!("CARGO_PKG_VERSION")
    )?;
    writeln!(
        out,
        "board: {}",
        snapshot.board.as_deref().unwrap_or("unknown")
    )?;
    writeln!(
        out,
        "sample: {} ms    updated: {}    Ctrl-C to quit",
        interval.as_millis(),
        unix_timestamp()
    )?;
    writeln!(out)?;
    writeln!(out, "---- cpu/gpu freq/temp/usage ----")?;

    for core in &snapshot.cpu_cores {
        writeln!(out, "{}", format_core(core))?;
    }

    writeln!(out, "{}", format_gpu(&snapshot.gpu))?;

    if let Some(memory) = &snapshot.memory {
        writeln!(out, "---- memory/swap usage ----")?;
        writeln!(out, "{}", format_memory_row("mem", Some(&memory.memory)))?;
        writeln!(out, "{}", format_memory_row("swap", memory.swap.as_ref()))?;
    }
    writeln!(out, "----")?;

    Ok(())
}

fn format_core(core: &CpuCore) -> String {
    let label = format!("cpu{}", core.id);

    format_device_row(
        &label,
        format_frequency_pair(core.frequency_mhz, core.max_frequency_mhz),
        format_compact_temperature(core.temperature_celsius),
        format_compact_usage(Some(core.usage_percent)),
        bar(core.usage_percent, 24),
    )
}

fn format_gpu(gpu: &GpuSnapshot) -> String {
    let usage = gpu.usage_percent;

    format_device_row(
        "gpu",
        format_frequency_pair(gpu.frequency_mhz, gpu.max_frequency_mhz),
        format_compact_temperature(gpu.temperature_celsius),
        format_compact_usage(usage),
        usage
            .map(|usage| bar(usage, 24))
            .unwrap_or_else(|| ".".repeat(24)),
    )
}

fn format_memory_row(label: &str, usage: Option<&MemoryUsage>) -> String {
    let value = usage
        .map(|usage| format_memory_pair(usage.used_gib, usage.total_gib))
        .unwrap_or_else(|| "n/a".to_string());
    let percent = usage
        .map(|usage| format_compact_usage(Some(usage.usage_percent)))
        .unwrap_or_else(|| "n/a".to_string());
    let bar = usage
        .map(|usage| bar(usage.usage_percent, 24))
        .unwrap_or_else(|| ".".repeat(24));

    format!(
        "{label:<label_width$} {value:>capacity_width$} {percent:>usage_width$} [{bar}]",
        label_width = LABEL_WIDTH,
        capacity_width = CAPACITY_WIDTH,
        usage_width = USAGE_WIDTH,
    )
}

fn format_device_row(
    label: &str,
    frequency: String,
    temperature: String,
    usage: String,
    bar: String,
) -> String {
    format!(
        "{label:<label_width$} {frequency:>frequency_width$} {temperature:>temperature_width$} {usage:>usage_width$} [{bar}]",
        label_width = LABEL_WIDTH,
        frequency_width = FREQUENCY_WIDTH,
        temperature_width = TEMPERATURE_WIDTH,
        usage_width = USAGE_WIDTH,
    )
}

fn format_compact_usage(value: Option<f32>) -> String {
    value
        .map(|value| format!("{value:.1}%"))
        .unwrap_or_else(|| "n/a".to_string())
}

fn bar(percent: f32, width: usize) -> String {
    let filled = ((percent.clamp(0.0, 100.0) / 100.0) * width as f32).round() as usize;
    let empty = width.saturating_sub(filled);
    format!("{}{}", "#".repeat(filled), ".".repeat(empty))
}

fn format_compact_temperature(value: Option<f32>) -> String {
    value
        .map(|value| format!("{value:.1}C"))
        .unwrap_or_else(|| "n/a".to_string())
}

fn format_frequency_pair(current: Option<f32>, max: Option<f32>) -> String {
    match (current, max) {
        (Some(current), Some(max)) => format!("{current:.0}/{max:.0}MHZ"),
        (Some(current), None) => format!("{current:.0}/n/aMHZ"),
        (None, Some(max)) => format!("n/a/{max:.0}MHZ"),
        (None, None) => "n/aMHZ".to_string(),
    }
}

fn format_memory_pair(used_gib: f32, total_gib: f32) -> String {
    format!("{used_gib:.1}/{total_gib:.1}GB")
}

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn parse_args(mut args: impl Iterator<Item = String>) -> Result<Config, String> {
    let mut config = Config::default();

    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                print_help();
                std::process::exit(0);
            }
            "--once" => config.once = true,
            "--no-clear" => config.clear_screen = false,
            "--interval-ms" => {
                let value = args
                    .next()
                    .ok_or_else(|| "--interval-ms requires a value".to_string())?;
                let millis = value
                    .parse::<u64>()
                    .map_err(|_| format!("invalid interval {value:?}"))?;
                if millis == 0 {
                    return Err("interval must be greater than zero".to_string());
                }
                config.interval = Duration::from_millis(millis);
            }
            _ => return Err(format!("unknown argument {arg:?}")),
        }
    }

    Ok(config)
}

fn print_help() {
    println!(
        "\
rktop - CPU/GPU monitor for RK3588 on mainline Linux

Usage:
  rktop [--interval-ms <ms>] [--once] [--no-clear]

Options:
  --interval-ms <ms>  Sampling interval in milliseconds (default: 1000)
  --once              Print one sample and exit
  --no-clear          Do not clear the terminal between samples
  -h, --help          Show this help
"
    );
}
