import os, requests
from ...typing import sha256, Dict, get_type_hints
import json

__all__ = [
    "my_api_key",
]


with open("config.json", "r", encoding="utf-8") as f:
    purgpt_api_key = json.load(f)["purgpt_api_key"]

purgpt_api_key = os.environ.get("PURGPT_API_KEY", purgpt_api_key)


url = 'https://purgpt.xyz/v1/bing'
model = [
    'bing'
]

supports_stream = False
needs_auth = False
working = True

def _create_completion(model: str, messages: list, stream: bool, **kwargs):

    base = ''
    for message in messages:
        base += '%s: %s\n' % (message['role'], message['content'])
    base += 'assistant:'

    headers = {
        'Content-Type': 'application/json',
		'Authorization': 'Bearer purgpt-b2vrs9w13oiyf14a7v4lt'
    }
    data = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": base,
            }
        ],
    }

    response = requests.post(url, headers=headers, data=json.dumps(data))
    if response.status_code == 200:
        yield response.json()['choices'][0]['message']['content']
    else:
        print(f"Error Occurred::{response.status_code}")
        return None


params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join(
        [f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
