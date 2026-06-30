use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::Instant;

#[derive(Debug, Clone)]
pub struct Snapshot {
    pub board: Option<String>,
    pub cpu_cores: Vec<CpuCore>,
    pub gpu: GpuSnapshot,
    pub memory: Option<MemorySnapshot>,
}

#[derive(Debug, Clone)]
pub struct CpuCore {
    pub id: usize,
    pub usage_percent: f32,
    pub frequency_mhz: Option<f32>,
    pub max_frequency_mhz: Option<f32>,
    pub temperature_celsius: Option<f32>,
}

#[derive(Debug, Clone)]
pub struct GpuSnapshot {
    pub usage_percent: Option<f32>,
    pub frequency_mhz: Option<f32>,
    pub max_frequency_mhz: Option<f32>,
    pub temperature_celsius: Option<f32>,
}

#[derive(Debug, Clone)]
pub struct MemorySnapshot {
    pub memory: MemoryUsage,
    pub swap: Option<MemoryUsage>,
}

#[derive(Debug, Clone)]
pub struct MemoryUsage {
    pub used_gib: f32,
    pub total_gib: f32,
    pub usage_percent: f32,
}

#[derive(Debug, Clone)]
pub struct PanthorProfilingState {
    pub path: PathBuf,
    pub value: u32,
}

#[derive(Debug, Clone)]
struct ThermalZone {
    label: String,
    celsius: f32,
}

#[derive(Debug, Clone, Copy, Default)]
struct CpuFrequency {
    current_mhz: Option<f32>,
    max_mhz: Option<f32>,
}

#[derive(Debug, Clone)]
pub struct GpuSample {
    pub timestamp: Instant,
    pub panthor: PanthorSample,
}

#[derive(Debug, Clone, Default)]
pub struct PanthorSample {
    pub clients: usize,
    pub engine_ns: Option<u64>,
    pub cycles: Option<u64>,
    pub max_frequency_hz: Option<u64>,
    pub profiling: Option<u32>,
    pub saw_fdinfo: bool,
}

#[derive(Debug, Clone, Default)]
pub struct CpuSample {
    pub total: CpuTimes,
    pub cores: BTreeMap<usize, CpuTimes>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct CpuTimes {
    user: u64,
    nice: u64,
    system: u64,
    idle: u64,
    iowait: u64,
    irq: u64,
    softirq: u64,
    steal: u64,
}

impl CpuTimes {
    fn idle_all(self) -> u64 {
        self.idle.saturating_add(self.iowait)
    }

    fn total(self) -> u64 {
        self.user
            .saturating_add(self.nice)
            .saturating_add(self.system)
            .saturating_add(self.idle)
            .saturating_add(self.iowait)
            .saturating_add(self.irq)
            .saturating_add(self.softirq)
            .saturating_add(self.steal)
    }
}

pub fn collect_snapshot(
    previous_cpu: &CpuSample,
    current_cpu: &CpuSample,
    previous_gpu: &GpuSample,
    current_gpu: &GpuSample,
) -> Snapshot {
    let cpu_frequencies = read_cpu_frequencies();
    let thermal_zones = read_thermal_zones();
    let gpu_usage = panthor_gpu_usage(previous_gpu, current_gpu);
    let gpu_frequency = read_gpu_frequency();
    let gpu_max_frequency = read_gpu_max_frequency();

    let cpu_cores = current_cpu
        .cores
        .iter()
        .map(|(id, current)| CpuCore {
            id: *id,
            usage_percent: previous_cpu
                .cores
                .get(id)
                .map(|previous| cpu_usage_percent(*previous, *current))
                .unwrap_or(0.0),
            frequency_mhz: cpu_frequencies
                .get(id)
                .and_then(|frequency| frequency.current_mhz),
            max_frequency_mhz: cpu_frequencies
                .get(id)
                .and_then(|frequency| frequency.max_mhz),
            temperature_celsius: select_cpu_core_temperature(&thermal_zones, *id),
        })
        .collect();

    Snapshot {
        board: read_board_name(),
        cpu_cores,
        gpu: GpuSnapshot {
            usage_percent: gpu_usage,
            frequency_mhz: gpu_frequency,
            max_frequency_mhz: gpu_max_frequency,
            temperature_celsius: select_gpu_temperature(&thermal_zones),
        },
        memory: read_memory_snapshot(),
    }
}

pub fn read_cpu_sample() -> io::Result<CpuSample> {
    parse_cpu_sample(&fs::read_to_string("/proc/stat")?)
}

pub fn read_gpu_sample() -> GpuSample {
    GpuSample {
        timestamp: Instant::now(),
        panthor: read_panthor_sample(),
    }
}

pub fn parse_cpu_sample(input: &str) -> io::Result<CpuSample> {
    let mut sample = CpuSample::default();

    for line in input.lines() {
        let mut parts = line.split_whitespace();
        let Some(label) = parts.next() else {
            continue;
        };

        if label == "cpu" {
            sample.total = parse_cpu_times(parts)?;
        } else if let Some(id) = label.strip_prefix("cpu").and_then(|s| s.parse().ok()) {
            sample.cores.insert(id, parse_cpu_times(parts)?);
        }
    }

    if sample.total.total() == 0 {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "missing aggregate CPU line in /proc/stat",
        ));
    }

    Ok(sample)
}

fn parse_cpu_times<'a>(parts: impl Iterator<Item = &'a str>) -> io::Result<CpuTimes> {
    let mut values = [0_u64; 8];

    for (index, part) in parts.take(8).enumerate() {
        values[index] = part.parse().map_err(|error| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("invalid CPU time value {part:?}: {error}"),
            )
        })?;
    }

    Ok(CpuTimes {
        user: values[0],
        nice: values[1],
        system: values[2],
        idle: values[3],
        iowait: values[4],
        irq: values[5],
        softirq: values[6],
        steal: values[7],
    })
}

pub fn cpu_usage_percent(previous: CpuTimes, current: CpuTimes) -> f32 {
    let total_delta = current.total().saturating_sub(previous.total());
    let idle_delta = current.idle_all().saturating_sub(previous.idle_all());

    if total_delta == 0 {
        return 0.0;
    }

    ((total_delta.saturating_sub(idle_delta)) as f32 * 100.0 / total_delta as f32).clamp(0.0, 100.0)
}

fn read_cpu_frequencies() -> BTreeMap<usize, CpuFrequency> {
    let mut frequencies = BTreeMap::new();
    let Ok(entries) = fs::read_dir("/sys/devices/system/cpu") else {
        return frequencies;
    };

    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(id) = name
            .to_string_lossy()
            .strip_prefix("cpu")
            .and_then(|s| s.parse::<usize>().ok())
        else {
            continue;
        };

        frequencies.insert(
            id,
            CpuFrequency {
                current_mhz: read_cpu_frequency(entry.path().join("cpufreq/scaling_cur_freq")),
                max_mhz: read_cpu_frequency(entry.path().join("cpufreq/scaling_max_freq")),
            },
        );
    }

    frequencies
}

fn read_cpu_frequency(path: impl AsRef<Path>) -> Option<f32> {
    fs::read_to_string(path)
        .ok()
        .and_then(|raw| raw.trim().parse::<f32>().ok())
        .map(|khz| khz / 1000.0)
}

fn read_memory_snapshot() -> Option<MemorySnapshot> {
    parse_memory_snapshot(&fs::read_to_string("/proc/meminfo").ok()?)
}

fn parse_memory_snapshot(input: &str) -> Option<MemorySnapshot> {
    let mut total_kib = None;
    let mut available_kib = None;
    let mut swap_total_kib = None;
    let mut swap_free_kib = None;

    for line in input.lines() {
        let mut parts = line.split_whitespace();
        match parts.next()? {
            "MemTotal:" => total_kib = parts.next().and_then(|value| value.parse::<u64>().ok()),
            "MemAvailable:" => {
                available_kib = parts.next().and_then(|value| value.parse::<u64>().ok())
            }
            "SwapTotal:" => {
                swap_total_kib = parts.next().and_then(|value| value.parse::<u64>().ok())
            }
            "SwapFree:" => swap_free_kib = parts.next().and_then(|value| value.parse::<u64>().ok()),
            _ => {}
        }
    }

    let memory = memory_usage_from_available(total_kib?, available_kib?)?;
    let swap = match (swap_total_kib, swap_free_kib) {
        (Some(total_kib), Some(free_kib)) => memory_usage_from_available(total_kib, free_kib),
        _ => None,
    };

    Some(MemorySnapshot { memory, swap })
}

fn memory_usage_from_available(total_kib: u64, available_kib: u64) -> Option<MemoryUsage> {
    if total_kib == 0 {
        return None;
    }

    let used_kib = total_kib.saturating_sub(available_kib);
    let used_gib = used_kib as f32 / 1_048_576.0;
    let total_gib = total_kib as f32 / 1_048_576.0;
    let usage_percent = (used_kib as f32 * 100.0 / total_kib as f32).clamp(0.0, 100.0);

    Some(MemoryUsage {
        used_gib,
        total_gib,
        usage_percent,
    })
}

fn read_thermal_zones() -> Vec<ThermalZone> {
    let mut zones = Vec::new();
    let Ok(entries) = fs::read_dir("/sys/class/thermal") else {
        return zones;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        let Some(name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };

        if !name.starts_with("thermal_zone") {
            continue;
        }

        let label = fs::read_to_string(path.join("type"))
            .ok()
            .map(|raw| clean_label(&raw))
            .filter(|label| !label.is_empty())
            .unwrap_or_else(|| name.to_string());

        let temp_path = path.join("temp");
        let Some(celsius) = fs::read_to_string(&temp_path)
            .ok()
            .and_then(|raw| parse_temperature_celsius(&raw))
        else {
            continue;
        };

        zones.push(ThermalZone { label, celsius });
    }

    zones.sort_by(|a, b| a.label.cmp(&b.label));
    zones
}

fn select_cpu_temperature(zones: &[ThermalZone]) -> Option<f32> {
    select_temperature(zones, |label| {
        let label = label.to_ascii_lowercase();
        (label.contains("cpu")
            || label.contains("soc")
            || label.contains("core")
            || label.contains("little")
            || label.contains("big")
            || label.contains("center"))
            && !label.contains("gpu")
            && !label.contains("npu")
    })
}

fn select_cpu_core_temperature(zones: &[ThermalZone], core_id: usize) -> Option<f32> {
    let preferred = match core_id {
        0..=3 => Some("littlecore"),
        4..=5 => Some("bigcore0"),
        6..=7 => Some("bigcore2"),
        _ => None,
    };

    preferred
        .and_then(|needle| {
            select_temperature(zones, |label| label.to_ascii_lowercase().contains(needle))
        })
        .or_else(|| select_cpu_temperature(zones))
}

fn select_gpu_temperature(zones: &[ThermalZone]) -> Option<f32> {
    select_temperature(zones, |label| {
        let label = label.to_ascii_lowercase();
        label.contains("gpu") || label.contains("mali") || label.contains("panthor")
    })
}

fn select_temperature(zones: &[ThermalZone], matches: impl Fn(&str) -> bool) -> Option<f32> {
    zones
        .iter()
        .filter(|zone| matches(&zone.label))
        .max_by(|a, b| a.celsius.total_cmp(&b.celsius))
        .map(|zone| zone.celsius)
}

fn panthor_gpu_usage(previous: &GpuSample, current: &GpuSample) -> Option<f32> {
    if current.panthor.profiling.is_none_or(|value| value < 2) {
        return None;
    }

    let elapsed = current
        .timestamp
        .saturating_duration_since(previous.timestamp);
    let elapsed_ns = elapsed.as_nanos() as f64;

    if elapsed_ns > 0.0 {
        if let (Some(previous_ns), Some(current_ns)) =
            (previous.panthor.engine_ns, current.panthor.engine_ns)
        {
            let delta = current_ns.saturating_sub(previous_ns) as f64;
            let usage = ((delta * 100.0) / elapsed_ns).clamp(0.0, 100.0) as f32;

            return Some(usage);
        }

        if let (Some(previous_cycles), Some(current_cycles), Some(max_frequency_hz)) = (
            previous.panthor.cycles,
            current.panthor.cycles,
            current
                .panthor
                .max_frequency_hz
                .or(previous.panthor.max_frequency_hz),
        ) {
            let elapsed_s = elapsed_ns / 1_000_000_000.0;
            let delta = current_cycles.saturating_sub(previous_cycles) as f64;
            let usage =
                ((delta * 100.0) / (elapsed_s * max_frequency_hz as f64)).clamp(0.0, 100.0) as f32;

            return Some(usage);
        }
    }

    if current.panthor.profiling.is_some_and(|value| value != 0) && current.panthor.clients == 0 {
        return Some(0.0);
    }

    None
}

fn read_panthor_sample() -> PanthorSample {
    let profiling = read_panthor_profiling();

    if profiling.is_none_or(|value| value < 2) {
        return PanthorSample {
            profiling,
            ..PanthorSample::default()
        };
    }

    let mut sample = PanthorSample {
        profiling,
        ..PanthorSample::default()
    };
    let mut clients = BTreeMap::new();
    let Ok(processes) = fs::read_dir("/proc") else {
        return sample;
    };

    for process in processes.flatten() {
        let pid = process.file_name().to_string_lossy().to_string();
        if !pid.bytes().all(|byte| byte.is_ascii_digit()) {
            continue;
        }

        let Ok(fdinfos) = fs::read_dir(process.path().join("fdinfo")) else {
            continue;
        };

        for fdinfo in fdinfos.flatten() {
            let Ok(content) = fs::read_to_string(fdinfo.path()) else {
                continue;
            };

            let Some(stats) = parse_panthor_fdinfo(&content) else {
                continue;
            };

            sample.saw_fdinfo = true;
            let key = stats
                .client_id
                .clone()
                .unwrap_or_else(|| format!("{pid}/{}", fdinfo.file_name().to_string_lossy()));
            clients.entry(key).or_insert(stats);
        }
    }

    sample.clients = clients.len();

    let mut engine_ns = 0_u64;
    let mut cycles = 0_u64;
    let mut saw_engine = false;
    let mut saw_cycles = false;

    for stats in clients.values() {
        if let Some(value) = stats.engine_ns {
            saw_engine = true;
            engine_ns = engine_ns.saturating_add(value);
        }

        if let Some(value) = stats.cycles {
            saw_cycles = true;
            cycles = cycles.saturating_add(value);
        }

        sample.max_frequency_hz = sample.max_frequency_hz.max(stats.max_frequency_hz);
    }

    sample.engine_ns = saw_engine.then_some(engine_ns);
    sample.cycles = saw_cycles.then_some(cycles);
    sample
}

fn read_panthor_profiling() -> Option<u32> {
    read_panthor_profiling_state().map(|state| state.value)
}

pub fn read_panthor_profiling_state() -> Option<PanthorProfilingState> {
    let mut profiling_paths = vec![PathBuf::from(
        "/sys/devices/platform/fb000000.gpu/profiling",
    )];

    if let Ok(entries) = fs::read_dir("/sys/bus/platform/drivers/panthor") {
        for entry in entries.flatten() {
            profiling_paths.push(entry.path().join("profiling"));
        }
    }

    for path in dedup_paths(profiling_paths) {
        let Ok(raw) = fs::read_to_string(&path) else {
            continue;
        };

        if let Ok(value) = raw.trim().parse() {
            return Some(PanthorProfilingState { path, value });
        }
    }

    None
}

#[derive(Debug, Clone, Default)]
struct PanthorFdinfo {
    client_id: Option<String>,
    engine_ns: Option<u64>,
    cycles: Option<u64>,
    max_frequency_hz: Option<u64>,
}

fn parse_panthor_fdinfo(input: &str) -> Option<PanthorFdinfo> {
    let mut driver = None;
    let mut stats = PanthorFdinfo::default();

    for line in input.lines() {
        let Some((key, value)) = line.split_once(':') else {
            continue;
        };

        let value = value.trim();
        match key {
            "drm-driver" => driver = Some(value),
            "drm-client-id" => stats.client_id = Some(value.to_string()),
            "drm-engine-panthor" => stats.engine_ns = first_u64(value),
            "drm-cycles-panthor" => stats.cycles = first_u64(value),
            "drm-maxfreq-panthor" => stats.max_frequency_hz = first_u64(value),
            _ => {}
        }
    }

    (driver == Some("panthor")).then_some(stats)
}

fn read_gpu_frequency() -> Option<f32> {
    read_gpu_devfreq_value("cur_freq")
}

fn read_gpu_max_frequency() -> Option<f32> {
    read_gpu_devfreq_value("max_freq")
}

fn read_gpu_devfreq_value(file_name: &str) -> Option<f32> {
    let mut paths = Vec::new();

    for dir in gpu_devfreq_dirs() {
        paths.push(dir.join(file_name));
    }

    for path in dedup_paths(paths) {
        let Ok(raw) = fs::read_to_string(&path) else {
            continue;
        };

        if let Some(value) = parse_frequency_mhz(&raw) {
            return Some(value);
        }
    }

    None
}

fn gpu_devfreq_dirs() -> Vec<PathBuf> {
    let mut dirs = vec![PathBuf::from("/sys/class/devfreq/fb000000.gpu")];

    if let Ok(entries) = fs::read_dir("/sys/class/devfreq") {
        for entry in entries.flatten() {
            let path = entry.path();
            let searchable = format!(
                "{} {}",
                path.file_name()
                    .and_then(|name| name.to_str())
                    .unwrap_or_default(),
                fs::read_link(&path)
                    .ok()
                    .and_then(|target| target.to_str().map(ToOwned::to_owned))
                    .unwrap_or_default()
            )
            .to_ascii_lowercase();

            if searchable.contains("gpu")
                || searchable.contains("mali")
                || searchable.contains("panthor")
            {
                dirs.push(path);
            }
        }
    }

    dedup_paths(dirs)
        .into_iter()
        .filter(|path| path.exists())
        .collect()
}

fn dedup_paths(paths: Vec<PathBuf>) -> Vec<PathBuf> {
    let mut seen = BTreeSet::new();
    let mut out = Vec::new();

    for path in paths {
        if seen.insert(path.clone()) {
            out.push(path);
        }
    }

    out
}

pub fn parse_temperature_celsius(input: &str) -> Option<f32> {
    let value = input.trim().parse::<f32>().ok()?;

    if value.abs() > 1000.0 {
        Some(value / 1000.0)
    } else {
        Some(value)
    }
}

pub fn parse_frequency_mhz(input: &str) -> Option<f32> {
    let value = first_number(input)?;

    if value > 10_000_000.0 {
        Some(value / 1_000_000.0)
    } else if value > 10_000.0 {
        Some(value / 1000.0)
    } else {
        Some(value)
    }
}

fn first_number(input: &str) -> Option<f32> {
    let mut started = false;
    let mut token = String::new();

    for ch in input.chars() {
        if ch.is_ascii_digit() || (ch == '.' && started) || (ch == '-' && !started) {
            started = true;
            token.push(ch);
        } else if started {
            break;
        }
    }

    token.parse::<f32>().ok()
}

fn first_u64(input: &str) -> Option<u64> {
    let mut started = false;
    let mut token = String::new();

    for ch in input.chars() {
        if ch.is_ascii_digit() {
            started = true;
            token.push(ch);
        } else if started {
            break;
        }
    }

    token.parse::<u64>().ok()
}

pub fn read_board_name() -> Option<String> {
    for path in [
        Path::new("/proc/device-tree/model"),
        Path::new("/sys/firmware/devicetree/base/model"),
    ] {
        let Ok(raw) = fs::read(path) else {
            continue;
        };

        let board = String::from_utf8_lossy(&raw)
            .trim_end_matches('\0')
            .trim()
            .to_string();

        if !board.is_empty() {
            return Some(board);
        }
    }

    None
}

fn clean_label(input: &str) -> String {
    input
        .trim_end_matches('\0')
        .trim()
        .trim_end_matches("_thermal")
        .trim_end_matches("-thermal")
        .replace('_', "-")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn parses_cpu_sample_and_usage() {
        let previous = parse_cpu_sample(
            "\
cpu  100 0 100 800 0 0 0 0 0 0
cpu0 50 0 50 400 0 0 0 0 0 0
cpu1 50 0 50 400 0 0 0 0 0 0
",
        )
        .unwrap();
        let current = parse_cpu_sample(
            "\
cpu  150 0 150 900 0 0 0 0 0 0
cpu0 70 0 80 450 0 0 0 0 0 0
cpu1 80 0 70 450 0 0 0 0 0 0
",
        )
        .unwrap();

        assert_eq!(current.cores.len(), 2);
        assert_eq!(cpu_usage_percent(previous.total, current.total), 50.0);
    }

    #[test]
    fn parses_panthor_fdinfo() {
        let stats = parse_panthor_fdinfo(
            "\
pos:    0
drm-driver:     panthor
drm-client-id:  10
drm-engine-panthor:     111110952750 ns
drm-cycles-panthor:     94439687187
drm-maxfreq-panthor:    1000000000 Hz
",
        )
        .unwrap();

        assert_eq!(stats.client_id.as_deref(), Some("10"));
        assert_eq!(stats.engine_ns, Some(111_110_952_750));
        assert_eq!(stats.cycles, Some(94_439_687_187));
        assert_eq!(stats.max_frequency_hz, Some(1_000_000_000));
    }

    #[test]
    fn calculates_panthor_engine_usage_delta() {
        let start = Instant::now();
        let previous = GpuSample {
            timestamp: start,
            panthor: PanthorSample {
                clients: 1,
                engine_ns: Some(1_000_000_000),
                profiling: Some(2),
                ..PanthorSample::default()
            },
        };
        let current = GpuSample {
            timestamp: start + Duration::from_secs(1),
            panthor: PanthorSample {
                clients: 1,
                engine_ns: Some(1_500_000_000),
                profiling: Some(2),
                ..PanthorSample::default()
            },
        };

        let usage = panthor_gpu_usage(&previous, &current);

        assert_eq!(usage, Some(50.0));
    }

    #[test]
    fn ignores_non_panthor_fdinfo() {
        assert!(parse_panthor_fdinfo("drm-driver: amdgpu\n").is_none());
    }

    #[test]
    fn parses_temperature_units() {
        assert_eq!(parse_temperature_celsius("42000\n"), Some(42.0));
        assert_eq!(parse_temperature_celsius("42\n"), Some(42.0));
    }

    #[test]
    fn parses_frequency_units() {
        assert_eq!(parse_frequency_mhz("800000000\n"), Some(800.0));
        assert_eq!(parse_frequency_mhz("1800000\n"), Some(1800.0));
        assert_eq!(parse_frequency_mhz("800\n"), Some(800.0));
    }

    #[test]
    fn parses_memory_snapshot() {
        let snapshot = parse_memory_snapshot(
            "\
MemTotal:       1048576 kB
MemFree:         262144 kB
MemAvailable:    786432 kB
SwapTotal:        524288 kB
SwapFree:         262144 kB
",
        )
        .unwrap();

        assert_eq!(snapshot.memory.used_gib, 0.25);
        assert_eq!(snapshot.memory.total_gib, 1.0);
        assert_eq!(snapshot.memory.usage_percent, 25.0);

        let swap = snapshot.swap.unwrap();
        assert_eq!(swap.used_gib, 0.25);
        assert_eq!(swap.total_gib, 0.5);
        assert_eq!(swap.usage_percent, 50.0);
    }

    #[test]
    fn omits_zero_sized_swap() {
        let snapshot = parse_memory_snapshot(
            "\
MemTotal:       1048576 kB
MemAvailable:    786432 kB
SwapTotal:             0 kB
SwapFree:              0 kB
",
        )
        .unwrap();

        assert!(snapshot.swap.is_none());
    }
}
