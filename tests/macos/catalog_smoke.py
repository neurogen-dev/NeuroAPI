"""Isolated managed-launch tests; production needs no Python runtime."""
import concurrent.futures
import json
import os
import signal
import time
from pathlib import Path
import subprocess
import sys
import tempfile

state = Path(sys.argv[1])
launchers = Path(sys.argv[2])


def model(slug):
    return dict(slug=slug, display_name=slug, description="Test model", supported_reasoning_levels=[],
                shell_type="shell_command", visibility="list", supported_in_api=True, priority=0,
                base_instructions="test", model_messages={"instructions_template": "test"},
                supports_reasoning_summary_parameter=False, support_verbosity=False,
                supports_parallel_tool_calls=False, truncation_policy={"mode": "tokens", "limit": 100},
                context_window=10000, max_context_window=10000, auto_compact_token_limit=8000,
                effective_context_window_percent=90, experimental_supported_tools=[], input_modalities=["text"],
                supports_search_tool=False, use_responses_lite=False, input_token_limit=8000, output_token_limit=2000)


def catalog(slug="test-model"):
    return {"models": [model(slug)], "default_model": slug}


def claude_catalog(slug="claude-opus-5-5"):
    return dict(model=slug, availableModels=[slug], enforceAvailableModels=True, fallbackModel=[],
                modelPicker={"options": [{"model": slug, "label": "Test"}], "replaceBuiltInOptions": True},
                env={"ANTHROPIC_DEFAULT_OPUS_MODEL": slug})


with tempfile.TemporaryDirectory(prefix="neuroapi-catalog-test-") as temp:
    root = Path(temp)
    curl = root / "curl"
    curl.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
auth = sys.stdin.read()
assert auth == 'header = "Authorization: Bearer test-neuroapi-token"\\n'
assert 'test-neuroapi-token' not in ' '.join(args)
assert args[:3] == ['--disable', '--config', '-']
assert '--location' not in args and '-L' not in args
assert args[args.index('--max-time')+1] == '20'
assert args[args.index('--max-filesize')+1] == '4194304'
assert args[args.index('--proto')+1] == '=https'
assert args[-1] in ['https://neuroapi.host/v1/codex/models', 'https://neuroapi.host/v1/claude-code/client-settings']
pathlib.Path(os.environ['TEST_FETCH_MARKER']).write_text('fetch')
if os.environ.get('TEST_FETCH_FAIL'):
    print('private upstream error')
    sys.exit(22)
sys.stdout.write(pathlib.Path(os.environ['TEST_PAYLOAD']).read_text())
sys.stdout.write('\\n' + os.environ.get('TEST_STATUS', '200'))
''')
    curl.chmod(0o700)
    # The subprocess mock interpreter uses an explicit test-only PATH entry.
    python = root / "python3"
    python.symlink_to(sys.executable)
    client_source = '''#!/usr/bin/env python3
import json, os, pathlib, stat, sys, time
if sys.argv[1:] == ['--version']:
    print(os.environ.get('TEST_VERSION', 'codex-cli 0.147.0' if pathlib.Path(sys.argv[0]).name == 'codex' else '2.1.280 (Claude Code)'))
    sys.exit(0)
a = sys.argv[1:]
if pathlib.Path(sys.argv[0]).name == 'codex':
    assert a[:2] == ['--profile', 'neuroapi-host']
    path = pathlib.Path(json.loads(a[a.index('-c') + 1].split('=', 1)[1]))
    payload = json.loads(path.read_text())
    overrides = [a[i+1] for i in range(len(a)-1) if a[i] == '-c']
    assert json.loads(next(v.split('=', 1)[1] for v in overrides if v.startswith('model='))) == payload['models'][0]['slug']
    assert '--model' not in a[:-2]
else:
    path = pathlib.Path(a[a.index('--settings') + 1])
    payload = json.loads(path.read_text())
    assert payload['env']['ANTHROPIC_BASE_URL'] == 'https://neuroapi.host/v1/claude-code'
    assert 'apiKeyHelper' in payload and 'test-neuroapi-token' not in path.read_text()
    neutralized = ['ANTHROPIC_SMALL_FAST_MODEL', 'CLAUDE_CODE_SUBAGENT_MODEL', 'ANTHROPIC_DEFAULT_MODEL',
                   'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY', 'CLAUDE_CODE_OAUTH_TOKEN',
                   'ANTHROPIC_CUSTOM_HEADERS', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX',
                   'CLAUDE_CODE_USE_FOUNDRY', 'CLAUDE_CODE_USE_ANTHROPIC_AWS', 'CLAUDE_CODE_USE_MANTLE']
    for k in ['ANTHROPIC_MODEL','ANTHROPIC_DEFAULT_OPUS_MODEL','ANTHROPIC_SMALL_FAST_MODEL','CLAUDE_CODE_SUBAGENT_MODEL','ANTHROPIC_BASE_URL'] + neutralized:
        assert k not in os.environ, k
    # Simulate a later settings.env merge from foreign user/project settings.
    merged_env = dict.fromkeys(neutralized, 'foreign-override')
    merged_env['ANTHROPIC_MODEL'] = 'foreign-model'
    merged_env.update(payload['env'])
    assert all(merged_env[k] == '' for k in neutralized)
    assert merged_env['ANTHROPIC_MODEL'] == payload['model']
    assert 'ANTHROPIC_DEFAULT_FABLE_MODEL' not in payload['env']
    assert os.environ['CLAUDE_CODE_USE_POWERSHELL_TOOL'] == '1'
    assert os.environ['CLAUDE_CODE_USE_NATIVE_FILE_SEARCH'] == '1'
assert stat.S_IMODE(path.stat().st_mode) == 0o600
assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700
assert 'test-neuroapi-token' not in path.read_text()
if os.environ.get('TEST_CHILD_STARTED'):
    pathlib.Path(os.environ['TEST_CHILD_STARTED']).write_text(str(path))
time.sleep(float(os.environ.get('TEST_CHILD_SLEEP', '0')))
print(json.dumps({'path':str(path), 'args':a, 'payload':payload}))
sys.exit(int(os.environ.get('TEST_CHILD_EXIT', '0')))
'''
    for name in ["codex", "claude"]:
        target = root / name
        target.write_text(client_source)
        target.chmod(0o700)
    base_env = dict(os.environ, PATH=str(root)+os.pathsep+os.environ["PATH"],
                    NEUROAPI_AGENTS_CURL_BIN=str(curl), ANTHROPIC_MODEL="inherited-model",
                    ANTHROPIC_DEFAULT_OPUS_MODEL="wrong-opus", ANTHROPIC_SMALL_FAST_MODEL="wrong-small",
                    ANTHROPIC_DEFAULT_MODEL="wrong-default",
                    CLAUDE_CODE_SUBAGENT_MODEL="wrong-subagent", ANTHROPIC_AUTH_TOKEN="wrong-token", ANTHROPIC_API_KEY="wrong-key",
                    ANTHROPIC_BASE_URL="https://other.invalid", CLAUDE_CODE_OAUTH_TOKEN="wrong-oauth",
                    ANTHROPIC_CUSTOM_HEADERS="Authorization: foreign-token", CLAUDE_CODE_USE_BEDROCK="1",
                    CLAUDE_CODE_USE_VERTEX="1", CLAUDE_CODE_USE_FOUNDRY="1", CLAUDE_CODE_USE_ANTHROPIC_AWS="1",
                    CLAUDE_CODE_USE_MANTLE="1", CLAUDE_CODE_USE_POWERSHELL_TOOL="1", CLAUDE_CODE_USE_NATIVE_FILE_SEARCH="1",
                    CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST="0")

    def run(payload, client="codex", success=True, user_args=None, **extra):
        nonlocal_marker = tempfile.NamedTemporaryFile(dir=root, delete=False)
        fixture = Path(nonlocal_marker.name)
        nonlocal_marker.close()
        fixture.write_text(payload if isinstance(payload, str) else json.dumps(payload))
        marker = fixture.with_suffix(".fetch")
        scratch = fixture.with_suffix(".private")
        scratch.mkdir()
        env = dict(base_env, TMPDIR=str(scratch), TEST_PAYLOAD=str(fixture), TEST_FETCH_MARKER=str(marker), **extra)
        result = subprocess.run([str(launchers / (client + "-neuroapi"))] + (user_args or ["prompt with spaces"]),
                                env=env, text=True, capture_output=True, timeout=30)
        assert not list(scratch.iterdir()), "Private snapshot survived launch completion"
        assert "test-neuroapi-token" not in result.stdout + result.stderr
        assert "private upstream error" not in result.stdout + result.stderr
        if success:
            assert result.returncode == int(extra.get("TEST_CHILD_EXIT", "0")), result.stderr
            observed = json.loads(result.stdout)
            assert observed["args"][-1] == (user_args or ["prompt with spaces"])[-1]
            assert not Path(observed["path"]).parent.exists(), "Private snapshot survived client exit"
            return observed
        assert result.returncode != 0 and not result.stdout, result
        return marker.exists()

    first = run(catalog())
    second = run(catalog("changed-model"))
    assert second["payload"]["models"][0]["slug"] == "changed-model"
    assert first["path"] != second["path"]
    run(catalog(), user_args=['--model', 'explicit-user-model'])
    run(claude_catalog(), client="claude")
    security_log = Path(os.environ['NEUROAPI_AGENTS_SECURITY_LOG'])
    for host_managed in ['1', 'true', 'yes', 'on', ' TRUE ', '\tOn\n', ' YeS ', ' 1 ']:
        before = security_log.read_bytes()
        assert not run(claude_catalog(), client="claude", success=False,
                       CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST=host_managed)
        assert security_log.read_bytes() == before, "Host-managed launch read credentials"
    for host_unmanaged in ['', 'false', '0', 'off']:
        run(claude_catalog(), client="claude", CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST=host_unmanaged)
    hidden = claude_catalog()
    hidden['availableModels'].append('claude-opus-4.8')
    run(hidden, client="claude")
    wrong_family = claude_catalog()
    wrong_family['env']['ANTHROPIC_DEFAULT_FABLE_MODEL'] = wrong_family['model']
    run(wrong_family, client="claude", success=False)
    hidden_default = dict(hidden, model='claude-opus-4.8')
    run(hidden_default, client="claude", success=False)
    hidden_codex = catalog()
    hidden_codex['models'][0]['visibility'] = 'hide'
    run(hidden_codex, success=False)
    unsupported_codex = catalog()
    unsupported_codex['models'][0]['supported_in_api'] = False
    run(unsupported_codex, success=False)
    run(catalog(), TEST_CHILD_EXIT="7")
    for malformed in ["not json", {"models": [], "default_model":"x"}, {"models":[model("x")],"default_model":"missing"},
                      {"models":[model("x"), model("x")],"default_model":"x"},
                      dict(catalog(), apiKeyHelper="bad"), "x" * (4194304 + 10)]:
        run(malformed, success=False)
    echoed = catalog("test-neuroapi-token")
    run(echoed, success=False)
    run(json.dumps(echoed).replace("test-neuroapi-token", "test-neuroapi-\\u0074oken"), success=False)
    run(catalog(), success=False, TEST_STATUS="302")
    run(catalog(), success=False, TEST_FETCH_FAIL="403")
    assert not run(catalog(), success=False, TEST_VERSION="codex-cli 0.146.9")
    assert not run(claude_catalog(), client="claude", success=False, TEST_VERSION="2.1.279 (Claude Code)")
    for invalid in [dict(claude_catalog(), apiKeyHelper="bad"), dict(claude_catalog(), availableModels=[]),
                    dict(claude_catalog(), env={"ANTHROPIC_AUTH_TOKEN":"evil"}),
                    dict(claude_catalog(), fallbackModel=["other"]), dict(claude_catalog(), model="missing")]:
        run(invalid, client="claude", success=False)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(run, catalog("concurrent-" + str(i)), TEST_CHILD_SLEEP="0.5") for i in range(2)]
        outputs = [j.result() for j in jobs]
        assert outputs[0]["path"] != outputs[1]["path"]
    signal_fixture = root / "signal.json"
    signal_fixture.write_text(json.dumps(catalog()))
    signal_started = root / "signal-started"
    signal_env = dict(base_env, TEST_PAYLOAD=str(signal_fixture), TEST_FETCH_MARKER=str(root / "signal-fetch"),
                      TEST_CHILD_STARTED=str(signal_started), TEST_CHILD_SLEEP="20")
    proc = subprocess.Popen([str(launchers / "codex-neuroapi")], env=signal_env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        for _ in range(100):
            if signal_started.exists():
                break
            time.sleep(0.05)
        assert signal_started.exists(), "Child did not start"
        signal_snapshot = Path(signal_started.read_text()).parent
        proc.send_signal(signal.SIGTERM)
        stdout, stderr = proc.communicate(timeout=5)
        assert proc.returncode == 143 and not stdout
        assert not signal_snapshot.exists(), "Snapshot survived termination"
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.communicate()
    print("Managed catalog launch tests passed (fresh lists, validation, versions, credentials, cleanup, concurrency).")
