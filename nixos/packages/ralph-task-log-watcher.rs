//! Forward the local worker's durable logs through the existing task stream.
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{self, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::Duration;

use crate::stream_domain::StreamDomain;
use serde_json::{Value, json};

const CHUNK_LIMIT: u64 = 65_536;

pub(crate) fn spawn(
    streams: StreamDomain,
    mut shutdown: tokio::sync::watch::Receiver<()>,
) -> Option<tokio::task::JoinHandle<()>> {
    let directory = PathBuf::from(std::env::var_os("RALPH_API_TASK_LOG_DIR")?);
    Some(tokio::spawn(async move {
        let mut offsets = HashMap::new();
        loop {
            tokio::select! {
                _ = shutdown.changed() => break,
                _ = tokio::time::sleep(Duration::from_millis(500)) => {
                    if let Err(error) = poll_logs(&directory, &streams, &mut offsets) {
                        if error.kind() != io::ErrorKind::NotFound {
                            tracing::warn!(%error, "failed reading worker logs");
                        }
                    }
                }
            }
        }
    }))
}

fn poll_logs(
    directory: &Path,
    streams: &StreamDomain,
    offsets: &mut HashMap<PathBuf, u64>,
) -> io::Result<()> {
    for entry in fs::read_dir(directory)? {
        let entry = entry?;
        let path = entry.path();
        if !entry.file_type()?.is_file() || path.extension().is_none_or(|ext| ext != "json") {
            continue;
        }
        // The active marker duplicates a per-run record; only read the latter.
        if path.file_name().is_some_and(|name| name == "active.json") {
            continue;
        }
        let Ok(metadata) = fs::read(&path)
            .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).map_err(io::Error::other))
        else {
            continue;
        };
        let Some(task_id) = metadata.get("id").and_then(Value::as_str) else {
            continue;
        };
        // Never trust a path from JSON. Read only the adjacent regular .log file.
        let log = path.with_extension("log");
        if !fs::symlink_metadata(&log).is_ok_and(|meta| meta.file_type().is_file()) {
            continue;
        }
        let finished = metadata.get("phase").and_then(Value::as_str) == Some("finished");
        let offset = offsets.entry(log.clone()).or_default();
        for line in read_lines(&log, offset, finished)? {
            streams.publish(
                "task.log.line",
                "task",
                task_id,
                json!({
                    "line": line,
                    "source": "stdout",
                }),
            );
        }
    }
    Ok(())
}

fn read_lines(path: &Path, offset: &mut u64, finished: bool) -> io::Result<Vec<String>> {
    let mut file = File::open(path)?;
    if file.metadata()?.len() < *offset {
        *offset = 0;
    }
    file.seek(SeekFrom::Start(*offset))?;
    let mut bytes = Vec::new();
    file.take(CHUNK_LIMIT).read_to_end(&mut bytes)?;
    // Preserve an incomplete line until its next write, or the process exits.
    let end = if finished || bytes.len() as u64 == CHUNK_LIMIT {
        bytes.len()
    } else {
        bytes
            .iter()
            .rposition(|byte| *byte == b'\n')
            .map_or(0, |pos| pos + 1)
    };
    *offset += end as u64;
    Ok(String::from_utf8_lossy(&bytes[..end])
        .lines()
        .map(str::to_owned)
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::stream_domain::StreamSubscribeParams;
    use std::io::Write;

    #[test]
    fn append_partial_line_and_truncation() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("run.log");
        fs::write(&path, "first\npar").unwrap();
        let mut offset = 0;
        assert_eq!(read_lines(&path, &mut offset, false).unwrap(), ["first"]);
        assert!(read_lines(&path, &mut offset, false).unwrap().is_empty());
        File::options()
            .append(true)
            .open(&path)
            .unwrap()
            .write_all(b"tial\n")
            .unwrap();
        assert_eq!(read_lines(&path, &mut offset, false).unwrap(), ["partial"]);
        fs::write(&path, "new\n").unwrap();
        assert_eq!(read_lines(&path, &mut offset, false).unwrap(), ["new"]);
    }

    #[test]
    fn completed_process_flushes_final_line() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("run.log");
        fs::write(&path, "no newline").unwrap();
        let mut offset = 0;
        assert!(read_lines(&path, &mut offset, false).unwrap().is_empty());
        assert_eq!(
            read_lines(&path, &mut offset, true).unwrap(),
            ["no newline"]
        );
        assert!(read_lines(&path, &mut offset, true).unwrap().is_empty());
    }

    #[test]
    fn log_is_replayed_to_matching_task_without_duplicate_active_marker() {
        let dir = tempfile::tempdir().unwrap();
        let metadata = r#"{"id":"task-1","phase":"running","log":"/etc/passwd"}"#;
        fs::write(dir.path().join("run.json"), metadata).unwrap();
        fs::write(dir.path().join("active.json"), metadata).unwrap();
        fs::write(dir.path().join("run.log"), "actual agent output\n").unwrap();
        let streams = StreamDomain::new();
        let mut offsets = HashMap::new();
        poll_logs(dir.path(), &streams, &mut offsets).unwrap();
        poll_logs(dir.path(), &streams, &mut offsets).unwrap();
        let sub = streams
            .subscribe(
                StreamSubscribeParams {
                    topics: vec!["task.log.line".into()],
                    cursor: None,
                    replay_limit: Some(400),
                    filters: Some(json!({"taskId": "task-1"})),
                },
                "test",
            )
            .unwrap();
        let replay = streams
            .replay_for_subscription(&sub.subscription_id)
            .unwrap();
        assert_eq!(replay.events.len(), 1);
        assert_eq!(replay.events[0].resource.id, "task-1");
        assert_eq!(replay.events[0].payload["line"], "actual agent output");
        let other = streams
            .subscribe(
                StreamSubscribeParams {
                    topics: vec!["task.log.line".into()],
                    cursor: None,
                    replay_limit: Some(400),
                    filters: Some(json!({"taskId": "task-2"})),
                },
                "test",
            )
            .unwrap();
        assert!(
            streams
                .replay_for_subscription(&other.subscription_id)
                .unwrap()
                .events
                .is_empty()
        );
    }
}
