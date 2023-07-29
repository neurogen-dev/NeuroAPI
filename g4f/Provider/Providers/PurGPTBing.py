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

purgpt_api_key = config.get("purgpt_api_key", "purgpt-qhu7co84r41q2rpyw4m2v")
purgpt_api_key = os.environ.get("PURGPT_API_KEY", purgpt_api_key)

openai.api_key = purgpt_api_key
openai.api_base = "https://purgpt.xyz/v1/bing"

url = 'https://purgpt.xyz/v1/bing'
model = [
'bing'
]

supports_stream = True
needs_auth = False
working = True

def _create_completion(model: str, messages: list, stream: bool, **kwargs):
    response = openai.ChatCompletion.create(
        model=model,
        messages=messages,
        stream=stream
    )
    if stream:
        for chunk in response:
            yield chunk.choices[0].delta.get("content", "")
    else:
        yield response.choices[0]['message'].get("content", "")
            


params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join(
        [f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
