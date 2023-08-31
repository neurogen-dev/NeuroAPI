import sys
import time
from pathlib import Path
from auto_proxy import get_random_proxy, update_working_proxies
import threading

sys.path.append(str(Path(__file__).parent.parent))

import g4f


stream = False
response = g4f.ChatCompletion.create(
    model="OpenAssistant/oasst-sft-6-llama-30b-xor",
    messages=[{"role": "user", "content": "hello"}],
    stream=stream,
)

print(response)