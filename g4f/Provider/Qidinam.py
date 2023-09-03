import json, random, string, time

from aiohttp import ClientSession
from ..typing import Any, CreateResult
from .base_provider import AsyncProvider, format_prompt

class Qidinam(AsyncProvider):
    url = "https://ai.qidianym.net/api/chat-process"
    working = True
    supports_gpt_35_turbo = True
    supports_stream = True

    @classmethod
    async def create_async(
        cls,
        model: str,
        messages: dict[str, str],
        **kwargs: Any,
    ) -> CreateResult:
        
        base = ""
        for message in messages:
            base += "%s: %s\n" % (message["role"], message["content"])
        base += "assistant:"

        headers = {
            "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        }
        data: dict[str, Any] = {
            "prompt": base,
            "options": {},
            "systemMessage": "You are ChatGPT, a large language model trained by OpenAI. Follow the user's instructions carefully. Respond using markdown.",
            "temperature": kwargs.get("temperature", 0.8),
            "top_p": kwargs.get("top_p", 1),
        }
        url = "https://ai.qidianym.net/api/chat-process"

        # Use aiohttp for asynchronous HTTP requests
        async with ClientSession() as session:
            async with session.post(url, headers=headers, json=data) as response:
                response.raise_for_status()
                lines = response.text.strip().split("\n")
                res = json.loads(lines[-1])
                return await res["text"]

    @classmethod
    @property
    def params(cls):
        params = [
            ("model", "str"),
            ("messages", "list[dict[str, str]]"),
            ("stream", "bool"),
            ("temperature", "float"),
            ("top_p", "int"),
        ]
        param = ", ".join([": ".join(p) for p in params])
        return f"g4f.provider.{cls.__name__} supports: ({param})"
