"""Exercise the actual JXA desktop editor without credentials or user settings."""
import pathlib
import subprocess
import tempfile
import tomllib


EDITOR = pathlib.Path(__file__).resolve().parents[2] / "scripts/macos/desktop-config.js"


def render(original: str, expected_success: bool = True) -> str:
    with tempfile.TemporaryDirectory(prefix="neuroapi-desktop-config-") as temp:
        root = pathlib.Path(temp)
        (root / "original").write_text(original)
        (root / "model").write_text("gpt-6-sol")
        result = subprocess.run(
            ["/usr/bin/osascript", "-l", "JavaScript", str(EDITOR),
             str(root / "original"), str(root / "model"),
             str(root / "catalog.json"), "/tmp/synthetic-key-helper", str(root / "output")],
            capture_output=True, text=True, timeout=15,
        )
        assert (result.returncode == 0) == expected_success, result.stderr
        if not expected_success:
            assert not (root / "output").exists(), "Invalid config was staged"
            return ""
        output = (root / "output").read_text()
        config = tomllib.loads(output)
        assert config["web_search"] == "live"
        assert config["features"]["remote_plugin"] is False
        assert config["model"] == "gpt-6-sol"
        assert config["model_catalog_json"] == str(root / "catalog.json")
        assert config["model_providers"]["neuroapi_agents"]["supports_websockets"] is False
        return output


for fixture in ("", "[features]", "['features']\nplugins = true",
                '["features"]\n"remote_plugin" = true',
                '[features]\r\nremote_plugin = true\r\nplugins = true\r\n'):
    render(fixture)

preserved = render('''# user preferences
web_search = "cached"
[features]
plugins = true
remote_plugin = true # keep comment
multi_agent = true
[mcp_servers.demo]
url = "https://example.test/mcp"
''')
parsed = tomllib.loads(preserved)
assert parsed["features"]["plugins"] is True
assert parsed["features"]["multi_agent"] is True
assert parsed["mcp_servers"]["demo"]["url"] == "https://example.test/mcp"
assert "remote_plugin = false # keep comment" in preserved
assert preserved.count("[features]") == 1

for fixture in ("features = { plugins = true }", "features.plugins = true",
                "[features]\n[features]", "[features]\nremote_plugin = 'true'",
                "[features]\nremote_plugin = true\nremote_plugin = false"):
    render(fixture, expected_success=False)

print("macOS Desktop config tests passed.")
