#!/usr/bin/env python3
"""Poll a node endpoint, evaluate health checks, and persist a report."""

from __future__ import annotations

import argparse
import asyncio
import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


@dataclass
class CheckResult:
    name: str
    status: str
    details: str
    current: Any = None
    expected: Any = None
    previous: Any = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "status": self.status,
            "details": self.details,
            "current": self.current,
            "expected": self.expected,
            "previous": self.previous,
        }


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_value(raw: str) -> Any:
    low = raw.lower()
    if low in {"true", "false"}:
        return low == "true"
    try:
        if "." in raw:
            return float(raw)
        return int(raw)
    except ValueError:
        return raw


def get_path_value(obj: Any, path: str) -> Any:
    current = obj
    for token in path.split("."):
        if token == "":
            continue
        if isinstance(current, list) and token.isdigit():
            idx = int(token)
            if idx >= len(current):
                raise KeyError(f"List index {idx} out of range for path '{path}'")
            current = current[idx]
        elif isinstance(current, dict) and token in current:
            current = current[token]
        else:
            raise KeyError(f"Path '{path}' not found at token '{token}'")
    return current


def parse_check_spec(spec: str) -> tuple[str, Any]:
    try:
        path, value = [part.strip() for part in spec.split(",", 1)]
    except ValueError as exc:
        raise ValueError(f"Invalid --check format: '{spec}'") from exc
    return path, parse_value(value)


def parse_metric_threshold(spec: str) -> tuple[str, float]:
    try:
        name, value = [part.strip() for part in spec.split(",", 1)]
    except ValueError as exc:
        raise ValueError(f"Invalid --metric-threshold format: '{spec}'") from exc
    try:
        return name, float(value)
    except ValueError as exc:
        raise ValueError(f"Metric threshold value must be numeric: '{spec}'") from exc


def parse_metrics_text(text: str) -> dict[str, float]:
    metrics: dict[str, float] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = stripped.split()
        if len(parts) < 2:
            continue
        metric_name = parts[0].split("{", 1)[0]
        raw_value = parts[1]
        try:
            metrics[metric_name] = float(raw_value)
        except ValueError:
            continue
    return metrics


def request_http(url: str, method: str, timeout_seconds: int, body: bytes | None = None) -> tuple[int, float, bytes]:
    request = Request(url=url, method=method, data=body)
    if body is not None:
        request.add_header("Content-Type", "application/json")
    started = time.monotonic()
    with urlopen(request, timeout=timeout_seconds) as response:
        payload = response.read()
        latency_ms = (time.monotonic() - started) * 1000.0
        return response.status, latency_ms, payload


def prefixed(name: str, check: str) -> str:
    return f"{name}:{check}"


async def run_rpc_checks(args: argparse.Namespace) -> tuple[list[CheckResult], dict[str, Any]]:
    checks: list[CheckResult] = []
    endpoint_payload: dict[str, Any] = {}
    if not args.rpc_endpoint:
        return checks, endpoint_payload

    try:
        rpc_body = {
            "jsonrpc": "2.0",
            "method": args.rpc_method,
            "params": args.rpc_params,
            "id": 1,
        }
        status_code, latency_ms, raw_body = await asyncio.to_thread(
            request_http,
            args.rpc_endpoint,
            "POST",
            args.timeout_seconds,
            json.dumps(rpc_body).encode("utf-8"),
        )
        endpoint_payload = json.loads(raw_body.decode("utf-8"))
        checks.append(
            CheckResult(
                name=prefixed("rpc", "endpoint_reachable"),
                status="pass",
                details="RPC endpoint responded successfully.",
                current=True,
                expected=True,
            )
        )
        checks.append(
            CheckResult(
                name=prefixed("rpc", "http_status"),
                status="pass" if status_code == args.expected_status else "fail",
                details=f"RPC HTTP status code was {status_code}.",
                current=status_code,
                expected=args.expected_status,
            )
        )
        checks.append(
            CheckResult(
                name=prefixed("rpc", "latency_ms"),
                status="pass" if latency_ms <= args.max_latency_ms else "fail",
                details=f"RPC request latency was {latency_ms:.2f} ms.",
                current=round(latency_ms, 2),
                expected=f"<= {args.max_latency_ms}",
            )
        )
    except HTTPError as exc:
        checks.append(
            CheckResult(
                name=prefixed("rpc", "endpoint_reachable"),
                status="fail",
                details=f"HTTP error {exc.code}: {exc.reason}",
                current=False,
                expected=True,
            )
        )
        return checks, endpoint_payload
    except URLError as exc:
        checks.append(
            CheckResult(
                name=prefixed("rpc", "endpoint_reachable"),
                status="fail",
                details=f"Connection error: {exc.reason}",
                current=False,
                expected=True,
            )
        )
        return checks, endpoint_payload
    except TimeoutError:
        checks.append(
            CheckResult(
                name=prefixed("rpc", "endpoint_reachable"),
                status="fail",
                details=f"Connection timed out after {args.timeout_seconds} seconds.",
                current=False,
                expected=True,
            )
        )
        return checks, endpoint_payload
    except json.JSONDecodeError as exc:
        checks.append(
            CheckResult(
                name=prefixed("rpc", "response_format"),
                status="fail",
                details=f"Failed to parse JSON response: {exc}",
            )
        )
        return checks, endpoint_payload
    except Exception as exc:  # noqa: BLE001
        checks.append(
            CheckResult(
                name=prefixed("rpc", "endpoint_reachable"),
                status="fail",
                details=f"Unexpected error: {exc}",
                current=False,
                expected=True,
            )
        )
        return checks, endpoint_payload

    rpc_error = endpoint_payload.get("error")
    checks.append(
        CheckResult(
            name=prefixed("rpc", "rpc_error"),
            status="pass" if rpc_error is None else "fail",
            details="RPC response has no error object." if rpc_error is None else "RPC response contains an error object.",
            current=rpc_error,
            expected=None,
        )
    )

    for check_spec in args.check:
        path, expected_value = parse_check_spec(check_spec)
        try:
            actual_value = get_path_value(endpoint_payload, path)
            passed = actual_value > expected_value
            checks.append(
                CheckResult(
                    name=prefixed("rpc", f"rpc_check:{path}"),
                    status="pass" if passed else "fail",
                    details=f"Checked {path} > {expected_value}.",
                    current=actual_value,
                    expected=f"> {expected_value}",
                )
            )
        except KeyError as exc:
            checks.append(
                CheckResult(
                    name=prefixed("rpc", f"rpc_check:{path}"),
                    status="fail",
                    details=str(exc),
                    expected=f"> {expected_value}",
                )
            )

    return checks, endpoint_payload


async def run_metrics_checks(
    args: argparse.Namespace, previous_report: dict[str, Any] | None
) -> tuple[list[CheckResult], dict[str, float]]:
    checks: list[CheckResult] = []
    metrics: dict[str, float] = {}
    if not args.metrics_endpoint:
        return checks, metrics

    try:
        status_code, latency_ms, raw_body = await asyncio.to_thread(
            request_http,
            args.metrics_endpoint,
            "GET",
            args.timeout_seconds,
            None,
        )
        metrics = parse_metrics_text(raw_body.decode("utf-8", errors="replace"))
        checks.append(
            CheckResult(
                name=prefixed("metrics", "endpoint_reachable"),
                status="pass",
                details="Metrics endpoint responded successfully.",
                current=True,
                expected=True,
            )
        )
        checks.append(
            CheckResult(
                name=prefixed("metrics", "http_status"),
                status="pass" if status_code == args.expected_status else "fail",
                details=f"Metrics HTTP status code was {status_code}.",
                current=status_code,
                expected=args.expected_status,
            )
        )
        checks.append(
            CheckResult(
                name=prefixed("metrics", "latency_ms"),
                status="pass" if latency_ms <= args.max_latency_ms else "fail",
                details=f"Metrics request latency was {latency_ms:.2f} ms.",
                current=round(latency_ms, 2),
                expected=f"<= {args.max_latency_ms}",
            )
        )
    except HTTPError as exc:
        checks.append(
            CheckResult(
                name=prefixed("metrics", "endpoint_reachable"),
                status="fail",
                details=f"HTTP error {exc.code}: {exc.reason}",
                current=False,
                expected=True,
            )
        )
        return checks, metrics
    except URLError as exc:
        checks.append(
            CheckResult(
                name=prefixed("metrics", "endpoint_reachable"),
                status="fail",
                details=f"Connection error: {exc.reason}",
                current=False,
                expected=True,
            )
        )
        return checks, metrics
    except TimeoutError:
        checks.append(
            CheckResult(
                name=prefixed("metrics", "endpoint_reachable"),
                status="fail",
                details=f"Connection timed out after {args.timeout_seconds} seconds.",
                current=False,
                expected=True,
            )
        )
        return checks, metrics
    except Exception as exc:  # noqa: BLE001
        checks.append(
            CheckResult(
                name=prefixed("metrics", "endpoint_reachable"),
                status="fail",
                details=f"Unexpected error: {exc}",
                current=False,
                expected=True,
            )
        )
        return checks, metrics

    for metric in args.require_metric:
        exists = metric in metrics
        checks.append(
            CheckResult(
                name=prefixed("metrics", f"metric_present:{metric}"),
                status="pass" if exists else "fail",
                details=f"Metric '{metric}' {'found' if exists else 'not found'}.",
                current=exists,
                expected=True,
            )
        )

    for threshold_spec in args.metric_threshold:
        metric_name, expected = parse_metric_threshold(threshold_spec)
        actual = metrics.get(metric_name)
        if actual is None:
            checks.append(
                CheckResult(
                    name=prefixed("metrics", f"metric_threshold:{metric_name}"),
                    status="fail",
                    details=f"Metric '{metric_name}' not found for threshold evaluation.",
                    expected=f"> {expected}",
                )
            )
            continue
        passed = actual > expected
        checks.append(
            CheckResult(
                name=prefixed("metrics", f"metric_threshold:{metric_name}"),
                status="pass" if passed else "fail",
                details=f"Checked metric '{metric_name}' > {expected}.",
                current=actual,
                expected=f"> {expected}",
            )
        )

    previous_metrics = {}
    if previous_report:
        previous_metrics = previous_report.get("endpoint_payload", {}).get("metrics", {})
    for metric_name in args.monotonic_metric:
        current_value = metrics.get(metric_name)
        previous_value = previous_metrics.get(metric_name)
        if current_value is None:
            checks.append(
                CheckResult(
                    name=prefixed("metrics", f"metric_monotonic:{metric_name}"),
                    status="fail",
                    details=f"Metric '{metric_name}' is missing in current report.",
                )
            )
            continue
        if previous_value is None:
            checks.append(
                CheckResult(
                    name=prefixed("metrics", f"metric_monotonic:{metric_name}"),
                    status="pass",
                    details=f"No previous value for '{metric_name}', baseline established.",
                    current=current_value,
                )
            )
            continue
        passed = current_value >= previous_value
        checks.append(
            CheckResult(
                name=prefixed("metrics", f"metric_monotonic:{metric_name}"),
                status="pass" if passed else "fail",
                details=f"Metric '{metric_name}' should be non-decreasing.",
                current=current_value,
                previous=previous_value,
                expected=">= previous",
            )
        )

    return checks, metrics


async def run_once(args: argparse.Namespace, previous_report: dict[str, Any] | None) -> dict[str, Any]:
    rpc_task = run_rpc_checks(args)
    metrics_task = run_metrics_checks(args, previous_report)
    (rpc_checks, rpc_payload), (metrics_checks, metrics_payload) = await asyncio.gather(rpc_task, metrics_task)

    checks = [*rpc_checks, *metrics_checks]
    regressions: list[dict[str, Any]] = []
    previous_checks = {}
    if previous_report:
        for c in previous_report.get("checks", []):
            previous_checks[c["name"]] = c

    for check in checks:
        prior = previous_checks.get(check.name)
        if prior and prior.get("status") == "pass" and check.status == "fail":
            regressions.append(
                {
                    "check": check.name,
                    "type": "pass_to_fail",
                    "previous_status": prior.get("status"),
                    "current_status": check.status,
                    "details": check.details,
                }
            )

    overall_status = "healthy" if all(c.status == "pass" for c in checks) else "unhealthy"
    return {
        "timestamp_utc": now_iso(),
        "endpoints": {
            "rpc": args.rpc_endpoint,
            "metrics": args.metrics_endpoint,
        },
        "overall_status": overall_status,
        "checks": [c.as_dict() for c in checks],
        "regressions": regressions,
        "endpoint_payload": {
            "rpc": rpc_payload,
            "metrics": metrics_payload,
        },
    }


def load_previous_report(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        content = path.read_text(encoding="utf-8")
    except json.JSONDecodeError:
        return None
    except OSError:
        return None

    stripped = content.strip()
    if not stripped:
        return None

    # Support both a single JSON object and JSONL history files.
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        for line in reversed(stripped.splitlines()):
            candidate = line.strip()
            if not candidate:
                continue
            try:
                parsed = json.loads(candidate)
            except json.JSONDecodeError:
                continue
            if isinstance(parsed, dict):
                return parsed
        return None


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(report, sort_keys=True))
        fh.write("\n")


def rotate_report_file(path: Path, max_backups: int) -> None:
    if max_backups <= 0:
        if path.exists():
            path.unlink()
        return
    oldest = path.with_name(f"{path.name}.{max_backups}")
    if oldest.exists():
        oldest.unlink()
    for idx in range(max_backups - 1, 0, -1):
        src = path.with_name(f"{path.name}.{idx}")
        dst = path.with_name(f"{path.name}.{idx + 1}")
        if src.exists():
            src.rename(dst)
    if path.exists():
        path.rename(path.with_name(f"{path.name}.1"))


def rotate_if_needed(path: Path, max_bytes: int, max_backups: int) -> None:
    if max_bytes <= 0 or not path.exists():
        return
    try:
        current_size = path.stat().st_size
    except OSError:
        return
    if current_size >= max_bytes:
        rotate_report_file(path, max_backups)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Poll RPC and/or metrics endpoints and append JSONL health reports."
    )
    parser.add_argument("--rpc-endpoint", help="JSON-RPC endpoint URL to query.")
    parser.add_argument("--metrics-endpoint", help="Prometheus metrics endpoint URL to query.")
    parser.add_argument("--report-path", required=True, help="Output path for JSONL report history.")
    parser.add_argument("--previous-report-path", help="Optional explicit path for previous report JSON.")
    parser.add_argument(
        "--rotate-max-bytes",
        type=int,
        default=0,
        help="Rotate report when file reaches this many bytes (0 disables rotation).",
    )
    parser.add_argument(
        "--rotate-backups",
        type=int,
        default=5,
        help="Number of rotated report backups to keep when rotation is enabled.",
    )
    parser.add_argument("--interval-seconds", type=int, default=60, help="Polling interval in seconds.")
    parser.add_argument("--iterations", type=int, default=1, help="How many polls to execute. 0 means infinite.")
    parser.add_argument("--timeout-seconds", type=int, default=10, help="HTTP timeout in seconds.")
    parser.add_argument("--expected-status", type=int, default=200, help="Expected HTTP status code.")
    parser.add_argument("--max-latency-ms", type=float, default=1500.0, help="Max acceptable response latency.")

    parser.add_argument("--rpc-method", default="health", help="JSON-RPC method used when --rpc-endpoint is set.")
    parser.add_argument(
        "--rpc-params",
        default="[]",
        help="JSON array/object params string passed to the RPC method.",
    )
    parser.add_argument(
        "--check",
        action="append",
        default=[],
        help="Extra RPC check in format: path,value and evaluates path > value (repeatable).",
    )

    parser.add_argument(
        "--require-metric",
        action="append",
        default=[],
        help="Metric name that must exist when --metrics-endpoint is set (repeatable).",
    )
    parser.add_argument(
        "--metric-threshold",
        action="append",
        default=[],
        help="Metric threshold in format: metric,value and evaluates metric > value (repeatable).",
    )
    parser.add_argument(
        "--monotonic-metric",
        action="append",
        default=[],
        help="Metric that should not decrease between reports (repeatable).",
    )

    args = parser.parse_args()
    if not args.rpc_endpoint and not args.metrics_endpoint:
        parser.error("At least one of --rpc-endpoint or --metrics-endpoint must be provided")
    if args.interval_seconds <= 0:
        parser.error("--interval-seconds must be > 0")
    if args.iterations < 0:
        parser.error("--iterations must be >= 0")
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be > 0")
    if args.rotate_max_bytes < 0:
        parser.error("--rotate-max-bytes must be >= 0")
    if args.rotate_backups < 0:
        parser.error("--rotate-backups must be >= 0")

    try:
        args.rpc_params = json.loads(args.rpc_params)
    except json.JSONDecodeError as exc:
        parser.error(f"--rpc-params must be valid JSON: {exc}")
    return args


async def main_async() -> int:
    args = parse_args()
    report_path = Path(args.report_path)
    previous_path = Path(args.previous_report_path) if args.previous_report_path else report_path

    executed = 0
    while args.iterations == 0 or executed < args.iterations:
        previous = load_previous_report(previous_path)
        report = await run_once(args, previous)
        rotate_if_needed(report_path, args.rotate_max_bytes, args.rotate_backups)
        write_report(report_path, report)

        checks_total = len(report["checks"])
        failed_count = sum(1 for c in report["checks"] if c["status"] == "fail")
        regressions_count = len(report["regressions"])
        print(
            f"[{report['timestamp_utc']}] status={report['overall_status']} "
            f"failed_checks={failed_count}/{checks_total} regressions={regressions_count} "
            f"report={report_path}"
        )

        executed += 1
        if args.iterations != 0 and executed >= args.iterations:
            break
        await asyncio.sleep(args.interval_seconds)

    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main_async()))
