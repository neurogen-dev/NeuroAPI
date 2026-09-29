"""Validate generated profiles without invoking Codex or credential helpers."""
import pathlib
import sys
import tomllib

profile_path, platform, helper_path, *secret_paths = sys.argv[1:]
raw = pathlib.Path(profile_path).read_text(encoding="utf-8")
profile = tomllib.loads(raw)
assert "model" not in profile  # The authenticated startup catalog supplies it.
assert profile["model_provider"] == "neuroapi"
assert profile["web_search"] == "disabled"
assert profile["features"] == {
    "multi_agent": False,
    "goals": False,
    "apps": False,
    "browser_use": False,
}
provider = profile["model_providers"]["neuroapi"]
assert provider["base_url"] == "https://neuroapi.host/v1/codex"
assert provider["wire_api"] == "responses"
assert provider["supports_websockets"] is True
assert set(provider) == {"name", "base_url", "wire_api", "supports_websockets", "auth"}
assert "test-neuroapi-token" not in raw
assert profile_path.endswith("neuroapi-host.config.toml")
auth = provider["auth"]
assert auth["timeout_ms"] == 5000
assert auth["refresh_interval_ms"] == 300000
if platform == "macos":
    assert auth["command"] == helper_path
    assert set(auth) == {"command", "timeout_ms", "refresh_interval_ms"}
elif platform == "windows":
    assert len(secret_paths) == 1
    assert auth["command"] == "powershell.exe"
    assert auth["args"] == [
        "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
        "-File", helper_path, "-SecretPath", secret_paths[0],
    ]
    assert set(auth) == {"command", "args", "timeout_ms", "refresh_interval_ms"}
else:
    raise AssertionError("Unknown platform")
print("Generated Codex profile contract passed.")
