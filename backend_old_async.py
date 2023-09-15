import os
import time
import json
import random
import string
import asyncio
import async_timeout
import aiohttp, aiofiles
import requests
import pytz
import logging
from datetime import datetime
from fastapi import FastAPI, Request
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.middleware.cors import CORSMiddleware
from typing import Any
import g4f
from g4f import ChatCompletion, Provider, BaseProvider
from g4f.models import ModelUtils
from cachetools import LRUCache

import aiofiles
import async_timeout

from fp.fp import FreeProxy
from embedding_processing import embedding_processing 
import concurrent.futures

app = FastAPI()
embedding_proc = embedding_processing()
LOG = logging.getLogger(__name__)

app.add_middleware(GZipMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_proxy():
    proxy = FreeProxy(rand=True, timeout=1).get()
    return proxy


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

    response = ChatCompletion.create(model=model, stream=stream, messages=messages, temperature=temperature, top_p=top_p, max_tokens=max_tokens, system_prompt="")

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
                        "content": response,
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

    def streaming():
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
                            "content": chunk,
                        },
                        "finish_reason": None,
                    }
                ],
            }
    
            content = json.dumps(completion_data, separators=(",", ":"))
            yield f"data: {content}\n\n"
            time.sleep(0.1)
    
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

@app.post('/v1/embeddings')
async def create_embedding(request: Request):
    j_input = await request.json()
    #model = embedding_processing()
    embedding = embedding_proc.embedding(text_list=j_input['input'])
    await log_event()
    return JSONResponse(
        embedding
        )

async def log_event():
    LOG.info('served')

@app.post("/v1/completions")
async def completions(request: Request):
    req_data = await request.json()
    model = req_data.get('model', 'text-davinci-003')
    prompt = req_data.get('prompt')
    messages = req_data.get('messages')
    temperature = req_data.get('temperature', 1.0)
    top_p = req_data.get('top_p', 1.0)
    max_tokens = req_data.get('max_tokens', 4096)

    response = g4f.Completion.create(model='text-davinci-003', prompt=prompt, temperature=temperature, top_p=top_p, max_tokens=max_tokens,)

    completion_id = "".join(random.choices(string.ascii_letters + string.digits, k=24))
    completion_timestamp = int(time.time())

    return {
      "id": f"cmpl-{completion_id}",
      "object": "text_completion",
      "created": completion_timestamp,
      "model": "text-davinci-003",
      "choices": [
        {
          "text": response,
          "index": 0,
          "logprobs": None,
          "finish_reason": "length"
        }
      ],
      "usage": {
        "prompt_tokens": None,
        "completion_tokens": None,
        "total_tokens": None
      }
    }

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
    for model_name, model in ModelUtils.convert.items():
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

def process_provider(provider_name, model_name):
    try:
        p = getattr(g4f.Provider, provider_name)
        provider_status = {
            "provider": provider_name,
            "model": model_name,
            "url": p.url,
            "status": ""
        }

        # Проверяем только модель 'gpt-3.5-turbo' для провайдеров Wewordle и Qidinam
        if provider_name in ['Wewordle', 'Qidinam', 'DeepAi', 'GetGpt', 'Yqcloud'] and model_name != 'gpt-3.5-turbo':
            provider_status['status'] = 'Inactive'
            #print(f"{provider_name} with {model_name} skipped")
            return provider_status

        try:
            response = ChatCompletion.create(model=model_name, provider=p,
                                                 messages=[{"role": "user", "content": "Say 'Hello World!'"}], stream=False)
            if any(word in response for word in ['Hello World', 'Hello', 'hello', 'world']):
                provider_status['status'] = 'Active'
                #print(f"{provider_name} with {model_name} say: {response}")
            else:
                provider_status['status'] = 'Inactive'
                #print(f"{provider_name} with {model_name} say: Inactive")
        except Exception as e:
            provider_status['status'] = 'Inactive'
           # print(f"{provider_name} with {model_name} say: Error")

        return provider_status
    except:
        return None

async def run_check_script():
    session = aiohttp.ClientSession()
    while True:
        models = [model for model in g4f.models.ModelUtils.convert if model.startswith('gpt-') or model.startswith('claude') or model.startswith('text-')]
        providers = [provider for provider in dir(g4f.Provider) if not provider.startswith('__')]

        status = {'data': []}
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = []
            for provider_name in providers:
                for model_name in models:
                    future = executor.submit(process_provider, provider_name, model_name)
                    futures.append(future)

            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result is not None and result['status'] == 'Active':
                    status['data'].append(result)

        print(status)
        status['key'] = "test"
        tz = pytz.timezone('Asia/Shanghai')
        now = datetime.now(tz)
        print(now)
        status['time'] = now.strftime("%Y-%m-%d %H:%M:%S")

        if status['data']:
            # Здесь мы используем aiofiles для асинхронного записывания в файл
            async with aiofiles.open('status.json', 'w') as f:
                await f.write(json.dumps(status))

        # Pause for 5 minutes before starting the next cycle
        time.sleep(360)

# Запуск асинхронных задач
async def run_tasks():
    while True:
        await asyncio.gather(run_check_script())
        await asyncio.sleep(300)
    
# Запуск приложения
def main():
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run_tasks())
    loop.close()

if __name__ == "__main__":
    main()