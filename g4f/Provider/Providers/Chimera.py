import re
import os
import openai
import openai.error
import logging
import sys
from dotenv import load_dotenv
import commentjson as json
from ...typing import sha256, Dict, get_type_hints

__all__ = [
    "my_api_key",
]

load_dotenv()

if os.path.exists("config.json"):
    with open("config.json", "r", encoding='utf-8') as f:
        config = json.load(f)
else:
    config = {}

my_api_key = config.get("openai_api_key", "")
my_api_key = os.environ.get("OPENAI_API_KEY", my_api_key)

openai.api_key = my_api_key
openai.api_base = "https://chimeragpt.adventblocks.cc/api/v1"

url = 'https://chimeragpt.adventblocks.cc/'
model = [
    'gpt-3.5-turbo-poe',
    'gpt-3.5-turbo-16k-poe',
    'gpt-4',
    'gpt-4-0314',
    'gpt-4-poe',
    'gpt-4-32k',
    'gpt-4-32k-poe',
    'claude-instant',
    'claude-instant-100k',
    'claude-2-100k',
    'sage'
]

supports_stream = True
needs_auth = False
working = True

def _create_completion(model: str, messages: list, stream: bool, **kwargs):
    try:
        response = openai.ChatCompletion.create(
            model=model,
            messages=messages,
            stream=stream
        )
        if stream:
            for chunk in response:
                yield chunk.choices[0].delta.get("content", ""), end="", flush=True
        else:
            yield response.choices[0]['message'].get("content", ""), end="", flush=True
            
    except openai.error.APIError as e:
        if e.http_status == 429:
            detail_pattern = re.compile(r'{"detail":"(.*?)"}')
            match = detail_pattern.search(e.user_message)
            if match:
                error_message = match.group(1)
                print(error_message)
                yield error_message
            else:
                print(e.user_message)
                yield e.user_message
        else:
            raise


params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join(
        [f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
