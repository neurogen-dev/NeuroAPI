import os
import uuid
import json
from Crypto.Cipher import AES
from aiohttp import ClientSession
from ..typing import Any, CreateResult, AsyncGenerator
from .base_provider import AsyncGeneratorProvider

class GetGpt(AsyncGeneratorProvider):
    url = 'https://chat.getgpt.world/'
    supports_stream = True
    working = True
    supports_gpt_35_turbo = True

    @classmethod
    async def create_async_generator(
        cls,
        model: str, 
        messages: list[dict[str, str]], 
        stream: bool, 
        **kwargs: Any
     ) -> AsyncGenerator:
        headers = {
            'Content-Type'  : 'application/json',
            'Referer'       : 'https://chat.getgpt.world/',
            'user-agent'    : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
        }
        
        data = json.dumps(
            {
                'messages'          : messages,
                'frequency_penalty' : kwargs.get('frequency_penalty', 0),
                'max_tokens'        : kwargs.get('max_tokens', 4000),
                'model'             : 'gpt-3.5-turbo',
                'presence_penalty'  : kwargs.get('presence_penalty', 0),
                'temperature'       : kwargs.get('temperature', 1),
                'top_p'             : kwargs.get('top_p', 1),
                'stream'            : True,
                'uuid'              : str(uuid.uuid4())
            }
        )
        
        json_data = {'signature': _encrypt(data)}
        
        async with ClientSession() as session:
            async with session.post('https://chat.getgpt.world/api/chat/stream',
                                    headers=headers, json=json_data) as res:
                res.raise_for_status()
                
                async for line in res.content.iter_any():
                    if b'content' in line:
                        line_json = json.loads(line.decode('utf-8').split('data: ')[1])
                        yield (line_json['choices'][0]['delta']['content'])

    @classmethod
    @property
    def params(cls):
        params = [
            ('model', 'str'),
            ('messages', 'list[dict[str, str]]'),
            ('stream', 'bool'),
            ('temperature', 'float'),
            ('presence_penalty', 'int'),
            ('frequency_penalty', 'int'),
            ('top_p', 'int'),
            ('max_tokens', 'int'),
        ]
        param = ', '.join([': '.join(p) for p in params])
        return f'g4f.provider.{cls.__name__} supports: ({param})'


def _encrypt(e: str):
    t = os.urandom(8).hex().encode('utf-8')
    n = os.urandom(8).hex().encode('utf-8')
    r = e.encode('utf-8')

    cipher = AES.new(t, AES.MODE_CBC, n)
    ciphertext = cipher.encrypt(_pad_data(r))

    return ciphertext.hex() + t.decode('utf-8') + n.decode('utf-8')

def _pad_data(data: bytes) -> bytes:
    block_size = AES.block_size
    padding_size = block_size - len(data) % block_size
    padding = bytes([padding_size] * padding_size)

    return data + padding
