import os
import time
import json
import random
import string
import socket
import nest_asyncio

import requests
from typing       import Any

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import logging
from .embedding_processing import embedding_processing

import g4f
from g4f import ChatCompletion, Provider, BaseProvider, models
from g4f.models import ModelUtils

nest_asyncio.apply()

app = Flask(__name__)
CORS(app)

LOG = logging.getLogger(__name__)
embedding_proc = embedding_processing()
    
@app.route("/chat/completions", methods=['POST'])
@app.route("/v1/chat/completions", methods=['POST'])
@app.route("/", methods=['POST'])
def chat_completions():
    request_data = request.get_json()
    model = request_data.get('model', 'gpt-3.5-turbo').replace("neuro-", "")
    messages = request_data.get('messages')
    stream = request_data.get('stream', False)
    streaming_ = request_data.get('stream', False)
    temperature = request_data.get('temperature', 1.0)
    top_p = request_data.get('top_p', 1.0)
    max_tokens = request_data.get('max_tokens', 1024)

    response = ChatCompletion.create(model=model, stream=stream, messages=messages, temperature=temperature, top_p=top_p, max_tokens=max_tokens, system_prompt="")

    completion_id = "".join(random.choices(string.ascii_letters + string.digits, k=28))
    completion_timestamp = int(time.time())
    
    if not streaming_:
        completion_timestamp = int(time.time())
        completion_id = ''.join(random.choices(
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', k=28))

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
                'id': f'chatcmpl-{completion_id}',
                'object': 'chat.completion.chunk',
                'created': completion_timestamp,
                'model': model,
                'choices': [
                    {
                        'index': 0,
                        'delta': {
                            'content': chunk,
                        },
                        'finish_reason': None,
                    }
                ],
            }

            content = json.dumps(completion_data, separators=(',', ':'))
            yield f'data: {content}\n\n'
            time.sleep(0.05)

        end_completion_data: dict[str, Any] = {
            'id': f'chatcmpl-{completion_id}',
            'object': 'chat.completion.chunk',
            'created': completion_timestamp,
            'model': model,
            'choices': [
                {
                    'index': 0,
                    'delta': {},
                    'finish_reason': 'stop',
                }
            ],
        }
        content = json.dumps(end_completion_data, separators=(',', ':'))
        yield f'data: {content}\n\n'

    return app.response_class(streaming(), mimetype='text/event-stream')

@app.route("/engines/text-embedding-ada-002/embeddings", methods=["POST"])
@app.route("/engines/text-similarity-davinci-001/embeddings", methods=["POST"])
@app.route('/v1/embeddings', methods=['POST'])
@app.route('/embeddings', methods=['POST'])
def create_embedding():
    j_input = request.get_json()
    #model = embedding_processing()
    embedding = embedding_proc.embedding(text_list=j_input['input'])
    log_event()
    return jsonify(
        embedding
        )

def log_event():
    LOG.info('served')
    
@app.route("/v1/dashboard/billing/subscription", methods=['GET'])
@app.route("/dashboard/billing/subscription", methods=['GET'])
def billing_subscription():
    return jsonify({
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


@app.route("/v1/dashboard/billing/usage", methods=['GET'])
@app.route("/dashboard/billing/usage", methods=['GET'])
def billing_usage():
    return jsonify({
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

@app.route("/v1/models", methods=['GET'])
@app.route("/models", methods=['GET'])
def models():
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
  return jsonify(model)

@app.route("/v1/providers", methods=['GET'])
@app.route("/providers", methods=['GET'])
def providers():
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
  return jsonify(providers_data)


