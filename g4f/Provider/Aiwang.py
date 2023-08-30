import random, requests, json
from ..typing import Any, CreateResult
from .base_provider import BaseProvider


class Aiwang(BaseProvider):
    url = "https://ai-wang.vercel.app"
    supports_stream = True
    supports_gpt_35_turbo = True
    supports_gpt_35_turbo_16k = True
    supports_gpt_35_turbo_16k_0613 = True
    supports_gpt_4 = True
    supports_gpt_4_0613 = True
    supports_gpt_4_32k = True
    supports_gpt_4_32k_0613 = True

    working = False

    @staticmethod
    def create_completion(
        model: str,
        messages: list[dict[str, str]],
        stream: bool,
        **kwargs: Any,
    ) -> CreateResult:
        base = ''
        for message in messages:
            base += '%s: %s\n' % (message['role'], message['content'])
        base += 'assistant:'
        
        headers = {
            "authority": "ai-wang.vercel.app",
            "accept": "*/*",
            "accept-language": "en,fr-FR;q=0.9,fr;q=0.8,es-ES;q=0.7,es;q=0.6,en-US;q=0.5,am;q=0.4,de;q=0.3,fa=0.2",
            "content-type": "application/json",
            "path":  "v1/chat/completions",
            "origin": f"{server}",
            "referer": f"{server}/",
            "x-requested-with": "XMLHttpRequest",
            'sec-ch-ua': '"Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"',
            'sec-ch-ua-mobile': '?0',
            'sec-ch-ua-platform': '"Windows"',
            'sec-fetch-dest': 'empty',
            'sec-fetch-mode': 'cors',
            'sec-fetch-site': 'same-origin',
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36',
        }

        json_data = {
            "messages": messages,
            "stream": stream,
            "model": model,
            "temperature": kwargs.get("temperature", 0.5),
            "presence_penalty": kwargs.get("presence_penalty", 0),
            "frequency_penalty": kwargs.get("frequency_penalty", 0),
            "top_p": kwargs.get("top_p", 1),
            "max_tokens": kwargs.get("max_tokens", 4096),
        }

        session = requests.Session()
        # init cookies from server
        session.get(f"{server}/")

        response = session.post(
            f"{server}/api/chat-stream",
            headers=headers,
            json=json_data,
            stream=stream,
        )
        response.encoding = "utf-8"
    
        try:
            # Find the first opening brace and the last closing brace
            start = response.text.find('{')
            end = response.text.rfind('}') + 1  # +1 to include the brace itself
    
            # Extract the JSON text
            json_text = response.text[start:end]
    
            # Convert the cleaned text to a Python dictionary
            response_dict = json.loads(json_text)
        except json.JSONDecodeError:
            print(f"Failed to decode JSON. Response text was: {response.text}")
            raise
    
        # Extract the desired message
        yield response_dict['choices'][0]['message']['content']
   

    @classmethod
    @property
    def params(cls):
        params = [
            ("model", "str"),
            ("messages", "list[dict[str, str]]"),
            ("stream", "bool"),
            ("temperature", "float"),
            ("presence_penalty", "int"),
            ("frequency_penalty", "int"),
            ("top_p", "int"),
            ("max_tokens", "int"),
            ("active_server", "int"),
        ]
        param = ", ".join([": ".join(p) for p in params])
        return f"g4f.provider.{cls.__name__} supports: ({param})"
