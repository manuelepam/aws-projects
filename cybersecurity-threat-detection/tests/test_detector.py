from src.detector import is_brute_force


def test_normal_login_is_not_brute_force() -> None:
    event = {
        "event_type": "LOGIN",
        "authentication_result": "SUCCESS",
        "failed_attempts_last_5m": 0,
    }

    assert is_brute_force(event) is False


def test_failed_login_burst_is_brute_force() -> None:
    event = {
        "event_type": "LOGIN",
        "authentication_result": "FAILURE",
        "failed_attempts_last_5m": 25,
    }

    assert is_brute_force(event) is True


def test_threshold_value_is_brute_force() -> None:
    event = {
        "event_type": "LOGIN",
        "authentication_result": "FAILURE",
        "failed_attempts_last_5m": 10,
    }

    assert is_brute_force(event) is True
