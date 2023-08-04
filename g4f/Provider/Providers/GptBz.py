import os, requests
from ...typing import sha256, Dict, get_type_hints
import json

url = "https://chat.gpt.bz"
model = ['gpt-4']
supports_stream = True
needs_auth = False
working = True


def _create_completion(model: str, messages: list, stream: bool, **kwargs):
    headers = {
        'authority': 'chat.gpt.bz',
        'authorization': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiNjRjZDNmYjVlZTU3Y2IwMDAxZWI2NzM4Iiwic291cmNlIjoiZ3B0LWRlbW8iLCJleHAiOjE2OTM3NjQ3ODl9.l0k5OxX5buvdHXUfRN521WdVjDdQEv9BrZCwYZ6qR44',
        'accept': 'text/event-stream',
        'accept-language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7,ja;q=0.6,zh-TW;q=0.5,zh;q=0.4',
        'content-type': 'application/json',
        'origin': 'https://chat.gpt.bz',
        'referer': 'https://chat.gpt.bz/',
        'sec-ch-ua': '"Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
        'x-requested-with': 'XMLHttpRequest',
    }

    json_data = {
        'messages': messages,
        'stream': True,
        'model': model,
        'temperature': 0.5,
        'presence_penalty': 0,
        'frequency_penalty': 0,
        'top_p': 1,
    }

    response = requests.post('https://chat.gpt.bz/api/openai/v1/chat/completions?conversation_id=So2JIBbGlKgK6UftuZnBh',
        headers=headers, json=json_data)
    print(response)
    print(response.json())
    response
    for line in response.iter_lines():
        if b'content' in line:
            line_json = json.loads(line.decode('utf-8').split('data: ')[1])
            yield (line_json['choices'][0]['delta']['content'])

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])