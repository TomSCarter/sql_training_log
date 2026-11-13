import time
import pathlib
import subprocess
from datetime import datetime, timezone

SQL_FILE = pathlib.Path("test.sql")
DB_FILE = "practice.duckdb"
LOG_FILE = pathlib.Path("sql_time_log.md")

def parse_question_tag(sql_text: str) -> str:
    first_line = sql_text.splitlines()[0].strip() if sql_text.strip() else ""
    if first_line.startswith("--"):
        return first_line.lstrip("-").strip()
    return "untagged"

def run_and_log(sql_text: str, prev_time: datetime | None, current_question: str) -> tuple[datetime, str]:
    now = datetime.now(timezone.utc)
    question = parse_question_tag(sql_text)

    # Reset timer delta if you started a new question tag
    if prev_time is None or question != current_question:
        delta_str = "START (0s)"
    else:
        secs = round((now - prev_time).total_seconds(), 1)
        delta_str = f"+{secs}s since last run"

    t0 = time.perf_counter()
    proc = subprocess.run(
        ["duckdb", "-readonly", "-csv", DB_FILE, "-c", sql_text],
        capture_output=True,
        text=True
    )
    exec_ms = round((time.perf_counter() - t0) * 1000, 1)

    if proc.returncode == 0:
        lines = [line for line in proc.stdout.strip().splitlines() if line]
        row_count = max(0, len(lines) - 1)
        status = f"SUCCESS ({row_count} rows, {exec_ms}ms)"
        error_block = ""
    else:
        status = f"ERROR ({exec_ms}ms)"
        err_lines = [l.strip() for l in proc.stderr.splitlines() if l.strip()]
        error_block = f"\n> **Error:** `{ ' | '.join(err_lines[:2]) }`\n"

    entry = (
        f"### [{now.strftime('%H:%M:%S')}] {question} — {delta_str} | {status}\n"
        f"{error_block}"
        f"```sql\n{sql_text.strip()}\n```\n\n---\n\n"
    )

    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(entry)

    print(f"[{now.strftime('%H:%M:%S')}] {question} ({delta_str}) -> {status}")
    return now, question

def main():
    print(f"Watching {SQL_FILE.resolve()} -> logging to {LOG_FILE.name}")
    last_mtime = SQL_FILE.stat().st_mtime if SQL_FILE.exists() else 0
    last_content = SQL_FILE.read_text(encoding="utf-8") if SQL_FILE.exists() else ""
    prev_time = None
    current_question = ""

    while True:
        try:
            if SQL_FILE.exists():
                mtime = SQL_FILE.stat().st_mtime
                if mtime != last_mtime:
                    last_mtime = mtime
                    time.sleep(0.05)
                    content = SQL_FILE.read_text(encoding="utf-8")
                    if content.strip() and content != last_content:
                        last_content = content
                        prev_time, current_question = run_and_log(content, prev_time, current_question)
            time.sleep(0.25)
        except KeyboardInterrupt:
            print("\nStopped watching.")
            break

if __name__ == "__main__":
    main()