import requests
import os
import json
from ...typing import sha256, Dict, get_type_hints

url = 'https://free.easychat.work'
model = ['gpt-3.5-turbo-16k', 'gpt-3.5-turbo']
supports_stream = True
needs_auth = False

def _create_completion(model: str, messages: list, stream: bool, temperature: float = 0.7, **kwargs):
    try:
        headers = {
            'Content-Type': 'application/json',
        }
        data = {
            'model': model,
            'temperature': 0.7,
            'presence_penalty': 0,
            'messages': messages,
        }
        response = requests.post(url + '/api/openai/v1/chat/completions',
                                 json=data, stream=stream)
        
        if response.status_code == 200:
            res = response.json()
            if 'choices' in res and len(res['choices']) > 0 and 'message' in res['choices'][0] and 'content' in res['choices'][0]['message']:
                yield res['choices'][0]['message']['content']
            else:
                raise KeyError("No 'choices' key in response or 'message' key in 'choices' or 'content' key in 'message'")
        else:
            print(f"Error Occurred::{response.status_code}")
            raise Exception(f"Easychat server error: Status Code {response.status_code}")
    except Exception as e:
        print(f"Error in Easychat provider: {e}")
        raise e 

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
