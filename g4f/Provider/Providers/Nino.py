import os, uuid, requests
from ...typing import sha256, Dict, get_type_hints

url = 'https://chimeragpt.ninomae.top'
model = ['gpt-3.5-turbo', 'gpt-4-0613', 'claude-instant-100k', 'gpt-4-poe']
supports_stream = True
needs_auth = True

models = {
    'gpt-4-0613': {
        "id":"gpt-4-0613",
        "name":"GPT-4-0613",
        "maxLength":24000,
        "tokenLimit":8000
    },
    'claude-instant-100k': {
        "id":"claude-instant-100k",
        "name":"CLAUDE-INSTANT-100K"
    },
    'gpt-4-poe': {
        "id":"gpt-4-poe",
        "name":"GPT-4-POE"
    },

    
}

def _create_completion(model: str, messages: list, stream: bool, **kwargs):

    print(kwargs)

    headers = {
        'authority': 'chimeragpt.ninomae.top',
        'content-type': 'application/json',
        'origin': 'https://chimeragpt.ninomae.top',
        'referer': 'https://chimeragpt.ninomae.top/zh',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36',
    }

    json_data = {
        'conversationId': str(uuid.uuid4()),
          'model': models[model],
          'messages': messages,
          'auth': 'oVy1CLB25mA43',
          'key': '',
          'prompt': "You are ChatGPT, a large language model trained by OpenAI. Follow the user's instructions carefully. Respond using markdown.",
      }

    response = requests.post('https://chimeragpt.ninomae.top/api/chat', 
                             headers=headers, json=json_data, stream=True)

    for token in response.iter_content(chunk_size=2046):
        yield (token.decode('utf-8'))

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])