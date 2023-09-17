import sys
import time
from pathlib import Path
import threading

sys.path.append(str(Path(__file__).parent.parent))

import g4f


stream = False
response = g4f.ChatCompletion.create(
    model="gpt-3.5-turbo-16k-0613",
    messages=[{"role": "user", "content": "hello"}],
    provider=g4f.Provider.Vercel,
    stream=stream,
)

print(response)