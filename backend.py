import os
import time
import json
import random
import string
import asyncio
import requests
import pytz
import logging
from datetime import datetime
from fastapi import FastAPI, Request
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.middleware.cors import CORSMiddleware
from typing import Any
from g4f import ChatCompletion, Provider, BaseProvider, models
from cachetools import LRUCache
import httpx
import check

app = FastAPI()
app.add_middleware(GZipMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Кэш для хранения данных из API
api_cache = LRUCache(maxsize=1000)

# Асинхронная функция для получения данных из API
async def get_data_from_api(url: str) -> Any:
    if url in api_cache:
        return api_cache[url]
    else:
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            data = response.json()
            api_cache[url] = data
            return data

@app.post("/chat/completions")
@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    req_data = await request.json()
    stream = req_data.get('stream', False)
    model = req_data.get('model', 'gpt-3.5-turbo')
    messages = req_data.get('messages')
    temperature = req_data.get('temperature', 1.0)
    top_p = req_data.get('top_p', 1.0)
    max_tokens = req_data.get('max_tokens', 4096)

    # Получение данных о провайдерах из API
    # Загрузка данных о провайдерах из локального файла
    with open('status.json', 'r') as f:
        provider_data = json.load(f)
    
    active_providers = [data['provider'] for data in provider_data['data'] if data['model'] == model and data['status'] == 'Active']
    
    if not active_providers:
        return JSONResponse({"error": "No active provider found for the model"})

    provider_name = random.choice(active_providers)
    provider = getattr(Provider, provider_name)

    response = ChatCompletion.create(model=model, stream=stream, messages=messages, provider=provider, temperature=temperature, top_p=top_p, max_tokens=max_tokens, system_prompt="")

    completion_id = "".join(random.choices(string.ascii_letters + string.digits, k=28))
    completion_timestamp = int(time.time())

    if not stream:
        return {
            "id": f"chatcmpl-{completion_id}",
            "object": "chat.completion",
            "created": completion_timestamp,
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": response.encode().decode(),
                    },
                    "finish_reason": "stop",
                }
            ],
            "usage": {
                "prompt_tokens": None,
                "completion_tokens": None,
                "total_tokens": None,
            },
        }

    async def streaming():
        for chunk in response:
            completion_data = {
                "id": f"chatcmpl-{completion_id}",
                "object": "chat.completion.chunk",
                "created": completion_timestamp,
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "delta": {
                            "content": chunk.encode().decode(),
                        },
                        "finish_reason": None,
                    }
                ],
            }

            content = json.dumps(completion_data, separators=(",", ":"))
            yield f"data: {content}\n\n"
            await asyncio.sleep(0.1)

        end_completion_data: dict[str, Any] = {
            "id": f"chatcmpl-{completion_id}",
            "object": "chat.completion.chunk",
            "created": completion_timestamp,
            "model": model,
            "choices": [
                {
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop",
                }
            ],
        }
        content = json.dumps(end_completion_data, separators=(",", ":"))
        yield f"data: {content}\n\n"

    return StreamingResponse(streaming(), media_type='text/event-stream')

@app.get("/v1/dashboard/billing/subscription")
@app.get("/dashboard/billing/subscription")
async def billing_subscription():
    return JSONResponse({
        "object": "billing_subscription",
        "has_payment_method": True,
        "canceled": False,
        "canceled_at": None,
        "delinquent": None,
        "access_until": 2556028800,
        "soft_limit": 6944500,
        "hard_limit": 166666666,
        "system_hard_limit": 166666666,
        "soft_limit_usd": 416.67,
        "hard_limit_usd": 9999.99996,
        "system_hard_limit_usd": 9999.99996,
        "plan": {
            "title": "Pay-as-you-go",
            "id": "payg"
        },
        "primary": True,
        "account_name": "OpenAI",
        "po_number": None,
        "billing_email": None,
        "tax_ids": None,
        "billing_address": {
            "city": "New York",
            "line1": "OpenAI",
            "country": "US",
            "postal_code": "NY10031"
        },
        "business_address": None
    })

@app.get("/v1/dashboard/billing/usage")
@app.get("/dashboard/billing/usage")
async def billing_usage():
    return JSONResponse({
        "object": "list",
        "daily_costs": [
            {
                "timestamp": time.time(),
                "line_items": [
                    {
                        "name": "GPT-4",
                        "cost": 0.0
                    },
                    {
                        "name": "Chat models",
                        "cost": 1.01
                    },
                    {
                        "name": "InstructGPT",
                        "cost": 0.0
                    },
                    {
                        "name": "Fine-tuning models",
                        "cost": 0.0
                    },
                    {
                        "name": "Embedding models",
                        "cost": 0.0
                    },
                    {
                        "name": "Image models",
                        "cost": 16.0
                    },
                    {
                        "name": "Audio models",
                        "cost": 0.0
                    }
                ]
            }
        ],
        "total_usage": 1.01
    })

@app.get("/v1/models")
@app.get("/models")
async def get_models():
    models_data = {"data": []}
    for model_name, model in models.ModelUtils.convert.items():
        models_data['data'].append({
            "id": model_name,
            "object": "model",
            "owned_by": model.base_provider,
            "tokens": 99999,
            "fallbacks": None,
            "endpoints": [
                "/v1/chat/completions"
            ],
            "limits": None,
            "permission": []
        })
    return JSONResponse(models_data)

@app.get("/v1/providers")
@app.get("/providers")
async def get_providers():
    providers_data = {"data": []}
    for provider_name in dir(Provider):
        if not provider_name.startswith('__'):
            try:
                provider = getattr(Provider, provider_name)
                providers_data["data"].append({
                    "provider": provider_name,
                    "model": list(provider.model),
                    "url": provider.url,
                    "working": bool(provider.working),
                    "supports_stream": bool(provider.supports_stream)
                })
            except:
                pass
    return JSONResponse(providers_data)

def setup_logging():
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)

    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)

    root_logger.addHandler(handler)

# Асинхронная функция для обновления кэша данных из API
async def update_api_cache():
    while True:
        try:
            # Обновление данных каждые 10 минут
            await asyncio.sleep(600)
            api_cache.clear()
        except:
            pass

# Запуск асинхронных задач
async def run_tasks():
    tasks = [
        asyncio.create_task(update_api_cache())
    ]
    await asyncio.gather(*tasks)

# Запуск приложения
def main():
    setup_logging()
    tz = pytz.timezone('Asia/Shanghai')
    now = datetime.now(tz)
    print(now)
    asyncio.run(run_tasks())
    check.main()

if __name__ == "__main__":
    main()