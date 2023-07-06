import requests
import json
import os
from typing import Dict, get_type_hints

url = "https://ava-alpha-api.codelink.io/api/chat"
model = "gpt-4"

supports_stream = True
needs_auth = False

def _create_completion(model: str, messages: list, stream: bool, **kwargs):

    headers = {
        "content-type": "application/json",
         }

    payload = {
        "model": model,
        "temperature": 0.6,
        "stream": stream,
        "messages": messages
    }

    response = requests.post(url, headers=headers, data=json.dumps(payload), stream=True)

    for line in response.iter_lines():
        decoded = line.decode('cp1251')
        if decoded.startswith('data: '):
            data_str = decoded.replace('data: ', '')
            # Check if the data_str is valid JSON before loading it
            try:
                data = json.loads(data_str)
                if 'choices' in data and 'delta' in data['choices'][0]:
                    delta = data['choices'][0]['delta']
                    content = delta.get('content', '')
                    finish_reason = delta.get('finish_reason', '')

                    if finish_reason == 'stop':
                        break
                    if content:
                        yield content
            except json.JSONDecodeError:
                # Handle the invalid JSON case
                print(f"Invalid JSON: {data_str}")

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
