import os
import time
import json
import random
import time

from fastapi import FastAPI, Request
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import json
from typing import List
import os
import random
import time
import asyncio
from starlette.middleware.cors import CORSMiddleware

import logging
import uvicorn

import g4f

from multiprocessing import Process

app = FastAPI()

app.add_middleware(GZipMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/chat/completions")
@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    req_data = await request.json()
    streaming = req_data.get('stream', False)
    streaming_ = req_data.get('stream', False)
    model = req_data.get('model')
    messages = req_data.get('messages')
    provider = req_data.get('provider', False)
    if model == 'bing':
        response = g4f.ChatCompletion.create(model=model, provider=g4f.Provider.BingHuan, stream=True,
                                             messages=messages)
    else:
    
        response = g4f.ChatCompletion.create(model=model, stream=streaming,
                                     messages=messages)
    
    if not streaming:
        while 'curl_cffi.requests.errors.RequestsError' in response:
            response = g4f.ChatCompletion.create(model=model, stream=streaming,
                                             messages=messages)

        completion_timestamp = int(time.time())
        completion_id = ''.join(random.choices(
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', k=28))

        return {
            'id': 'chatcmpl-%s' % completion_id,
            'object': 'chat.completion',
            'created': completion_timestamp,
            'model': model,
            'usage': {
                'prompt_tokens': None,
                'completion_tokens': None,
                'total_tokens': None
            },
            'choices': [{
                'message': {
                    'role': 'assistant',
                    'content': response
                },
                'finish_reason': 'stop',
                'index': 0
            }]
        }

    async def stream():
        completion_data = {
            'id': '',
            'object': 'chat.completion.chunk',
            'created': 0,
            'model': 'gpt-3.5-turbo-0301',
            'choices': [
                {
                    'delta': {
                        'content': ""
                    },
                    'index': 0,
                    'finish_reason': None
                }
            ]
        }

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
            time.sleep(0.05)

        completion_data['choices'][0]['finish_reason'] = "stop"
        completion_data['choices'][0]['delta']['content'] = ""
        yield 'data: %s\n\n' % json.dumps(completion_data, separators=(',' ':'))
        yield 'data: [DONE]\n\n'
    return StreamingResponse(stream(), media_type='text/event-stream')

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
}
)


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
}
)

@app.get("/v1/models")
@app.get("/models")
async def models():
  import g4f.models
  model = {"data":[]}
  for i in g4f.models.ModelUtils.convert:
    model['data'].append({
            "id": i,
            "object": "model",
            "owned_by": g4f.models.ModelUtils.convert[i].base_provider,
            "tokens": 99999,
            "fallbacks": None,
            "endpoints": [
                "/v1/chat/completions"
            ],
            "limits": None,
            "permission": []
        })
  return JSONResponse(model)

@app.get("/v1/providers")
@app.get("/providers")
async def providers():
  files = os.listdir("g4f/Provider/Providers")
  files = [f for f in files if os.path.isfile(os.path.join("g4f/Provider/Providers", f))]
  files.sort(key=str.lower)
  providers_data = {"data":[]}
  for file in files:
      if file.endswith(".py"):
          name = file[:-3]
          try:
              p = getattr(g4f.Provider,name)
              providers_data["data"].append({
              "provider": str(name),
              "model": list(p.model),
              "url": str(p.url),
              "working": bool(p.working),
              "supports_stream": bool(p.supports_stream)
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

def run_api_server():
    uvicorn.run("backend:app", host="0.0.0.0", port=1337)


if __name__ == "__main__":
    api_process = Process(target=run_api_server) 
    api_process.start()