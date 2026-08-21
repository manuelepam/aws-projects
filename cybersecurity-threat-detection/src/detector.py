import json
from pathlib import Path


BRUTE_FORCE_THRESHOLD = 10


def load_event(file_path: Path) -> dict:
    with file_path.open("r", encoding="utf-8") as event_file:
        return json.load(event_file)


def is_brute_force(event: dict) -> bool:
    return (
        event["event_type"] == "LOGIN"
        and event["authentication_result"] == "FAILURE"
        and event["failed_attempts_last_5m"] >= BRUTE_FORCE_THRESHOLD
    )


def main() -> None:
    normal_event_path = Path("sample-events/normal-login.json")
    normal_event = load_event(normal_event_path)

    suspicious_event_path = Path("sample-events/failed-login-burst.json")
    suspicious_event = load_event(suspicious_event_path)

    normal_result = is_brute_force(normal_event)
    suspicious_result = is_brute_force(suspicious_event)

    print(f"Normal event detected as brute force: {normal_result}")
    print(f"Suspicious event detected as brute force: {suspicious_result}")


if __name__ == "__main__":
    main()
