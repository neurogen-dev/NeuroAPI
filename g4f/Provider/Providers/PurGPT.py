import os, requests
from ...typing import sha256, Dict, get_type_hints
import json

__all__ = [
    "my_api_key",
]


with open("config.json", "r") as f:
    purgpt_api_key = json.load(f)["purgpt_api_key"]

purgpt_api_key = os.environ.get("PURGPT_API_KEY", purgpt_api_key)


url = 'https://beta.purgpt.xyz/openai/chat/completions'
models = {

    'gpt-3.5-turbo-16k-purgpt-api': 'gpt-3.5-turbo-16k',
    'gpt-3.5-turbo-purgpt-api': 'gpt-3.5-turbo',
    'text-davinci-003-purgpt-api': 'text-davinci-003',
}


supports_stream = True
needs_auth = False
working = True

def _create_completion(model: str, messages: list, stream: bool, **kwargs):

    base = ''
    for message in messages:
        base += '%s: %s\n' % (message['role'], message['content'])
    base += 'assistant:'

    headers = {
        'Content-Type': 'application/json',
		'Authorization': f'Bearer {purgpt_api_key}',
    }
    data = {
        "model": models[model],
        "messages": [
            {
                "role": "user",
                "content": base,
            }
        ],
        "stream": True
    }

    response = requests.post(url, headers=headers, data=json.dumps(data), stream=True)

    for chunk in response.iter_lines():
        if b'content' in chunk:
            data = json.loads(chunk.decode().split('data: ')[1])
            yield (data['choices'][0]['delta']['content'])


params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join(
        [f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
