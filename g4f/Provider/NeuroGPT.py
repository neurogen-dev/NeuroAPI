from __future__ import annotations

import re
import os
import openai
import json
import openai.error
from aiohttp import ClientSession

from ..typing import AsyncGenerator
from .base_provider import AsyncGeneratorProvider, format_prompt

openai.api_base = 'https://neuroapi.host/v1'
openai.api_key = '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'

class NeuroGPT(AsyncGeneratorProvider):
    url = "https://neuroapi.host"
    working = True
    supports_gpt_35_turbo = True
    supports_stream       = True

    @classmethod
    async def create_async_generator(
        cls,
        model: str,
        messages: list[dict[str, str]],
        stream: bool = True,
        proxy: str = None,
        **kwargs
    ) -> AsyncGenerator:

        try:
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
        except openai.error.APIError as e:
            if e.http_status == 429:
                detail_pattern = re.compile(r'{"detail":"(.*?)"}')
                match = detail_pattern.search(e.user_message)
                if match:
                    error_message = match.group(1)
                    yield error_message
                else:
                    yield e.user_message
            else:
                raise

    @classmethod
    @property
    def params(cls):
        params = [
            ("model", "str"),
            ("messages", "list[dict[str, str]]"),
            ("stream", "bool"),
            ("temperature", "float"),
        ]
        param = ", ".join([": ".join(p) for p in params])
        return f"g4f.provider.{cls.__name__} supports: ({param})"
