#Не работает, не могу понять как обойти ряд ограничнений
import requests
import os
import json
import random
import time
from ...typing import sha256, Dict, get_type_hints

url = 'https://api.fe8.cn'
model = ['gpt-3.5-turbo']
supports_stream = True
needs_auth = True

def _create_completion(model: str, messages: list, stream: bool, temperature: float = 0.7, **kwargs):
    headers = {
    'Content-Type': 'application/json',
    'Origin':'https://gpppt.com',
    'Referer':'https://gpppt.com/',
    'authority': 'api.fe8.cn',
    'Appid':'64893391d8fe7',
    'Appsecret': '243fe44e1fdfc0ca9d1aa4eb5659ca98',
    'Accept': 'text/event-stream',
    'Accept-Encoding': 'gzip, deflate, br',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7,ja;q=0.6,zh-TW;q=0.5,zh;q=0.4',
    'Access-Control-Allow-Origin': '*',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
}
    completion_data = {
        'model': model,
        'temperature': 0.7,
        'presence_penalty': 0,
        'messages': messages,
    }
    response = requests.post(url + '/v1/chat/completions', headers=headers,
                             data=completion_data, stream=True)
    print(response)
    
    for token in response:
            completion_id = ''.join(
                random.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', k=28))
            completion_timestamp = int(time.time())
            completion_data['id'] = f'chatcmpl-{completion_id}'
            completion_data['created'] = completion_timestamp
            completion_data['choices'][0]['delta']['content'] = token
            if token.startswith("an error occured"):
                completion_data['choices'][0]['delta']['content'] = "Server Response Error, please try again.\n"
                completion_data['choices'][0]['delta']['stop'] = "error"
                yield 'data: %s\n\ndata: [DONE]\n\n' % json.dumps(completion_data, separators=(',' ':'))
                return
            yield 'data: %s\n\n' % json.dumps(completion_data, separators=(',' ':'))
            time.sleep(0.1)

    completion_data['choices'][0]['finish_reason'] = "stop"
    completion_data['choices'][0]['delta']['content'] = ""
    yield 'data: %s\n\n' % json.dumps(completion_data, separators=(',' ':'))
    yield 'data: [DONE]\n\n'

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
