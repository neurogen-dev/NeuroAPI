import os,sys
import requests
from ...typing import get_type_hints

url = "https://aiservice.vercel.app/api/chat/answer"
model = ['gpt-3.5-turbo']
supports_stream = True
needs_auth = False


def _create_completion(model: str, messages: list, stream: bool, **kwargs):
    try:
        base = ''
        for message in messages:
            base += '%s: %s\n' % (message['role'], message['content'])
        base += 'assistant:'

        headers = {
            "accept": "*/*",
            "content-type": "text/plain;charset=UTF-8",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "same-origin",
            "Referer": "https://aiservice.vercel.app/chat",
        }
        data = {
            "input": base
        }
        response = requests.post(url, headers=headers, json=data, stream=True)
        
        if response.status_code == 200:
            _json = response.json()
            if 'data' in _json:
                yield _json['data']
            else:
                raise KeyError("No 'data' key in the response")
        else:
            print(f"Error Occurred::{response.status_code}")
            raise Exception(f"Vercel server error: Status Code {response.status_code}")
    except Exception as e:
        print(f"Error in Vercel provider: {e}")
        raise e 


params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join(
        [f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
