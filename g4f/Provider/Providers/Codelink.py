import os
import requests, re
from ...typing import sha256, Dict, get_type_hints

url = 'https://ava-alpha-api.codelink.io'
model = ['gpt-4']
supports_stream = False
needs_auth = False

def _create_completion(model: str, messages: list, stream: bool, **kwargs):
    chat = ''
    for message in messages:
        chat += '%s: %s\n' % (message['role'], message['content'])
    chat += 'assistant: '

    response = requests.get('https://chatgpt.ai/gpt-4/')

    nonce, post_id, _, bot_id = re.findall(r'data-nonce="(.*)"\n     data-post-id="(.*)"\n     data-url="(.*)"\n     data-bot-id="(.*)"\n     data-width', response.text)[0]

    headers = {
        "Content-Type": "application/json"
    }
    data = {
        'model': model,
        'temperature': 0.7,
        'stream': True,
        'messages': messages,
    },

    response = requests.post('https://chatgpt.ai/wp-admin/admin-ajax.php', 
                            headers=headers, data=data)

    yield (response.json()['data'])

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])