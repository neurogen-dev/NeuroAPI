import os
import time
import json
import random
import requests
import g4f
import time
from gevent import pywsgi
import socket
from flask import Flask, request, Response, jsonify
from flask_cors import CORS

from g4f import Model, ChatCompletion, Provider

app = Flask(__name__)
CORS(app)


@app.route("/chat/completions", methods=['POST'])
@app.route("/v1/chat/completions", methods=['POST'])
@app.route("/", methods=['POST'])
def chat_completions():
    streaming = request.json.get('stream', False)
    model = request.json.get('model', 'gpt-3.5-turbo')
    messages = request.json.get('messages')

    response = ChatCompletion.create(model=model, stream=streaming,
                                     messages=messages)

    if not streaming:
        while 'curl_cffi.requests.errors.RequestsError' in response:
            response = ChatCompletion.create(model=model, stream=streaming,
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
                'prompt_tokens': 0,
                'completion_tokens': 0,
                'total_tokens': 0
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

    def stream():
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
            time.sleep(0.1)

        completion_data['choices'][0]['finish_reason'] = "stop"
        completion_data['choices'][0]['delta']['content'] = ""
        yield 'data: %s\n\n' % json.dumps(completion_data, separators=(',' ':'))
        yield 'data: [DONE]\n\n'

    return app.response_class(stream(), mimetype='text/event-stream')


@app.route("/v1/dashboard/billing/subscription")
@app.route("/dashboard/billing/subscription")
def billing_subscription():
  return jsonify({
  "object": "billing_subscription",
  "has_payment_method": True,
  "canceled": False,
  "canceled_at": None,
  "delinquent": None,
  "access_until": 1690848000,
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
  "account_name": "Lemon SMith",
  "po_number": None,
  "billing_email": None,
  "tax_ids": None,
  "billing_address": {
    "city": "Hastings",
    "line1": " 2 Amherst Road",
    "country": "GB",
    "postal_code": "TN34 1TT"
  },
  "business_address": None
}
)


@app.route("/v1/dashboard/billing/usage")
@app.route("/dashboard/billing/usage")
def billing_usage():
  return jsonify({
  "object": "list",
  "daily_costs": [
    {
      "timestamp": 1688169600.0,
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
    },
    {
      "timestamp": 1688256000.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688342400.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688428800.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688515200.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688601600.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688688000.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688774400.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688860800.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1688947200.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689033600.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689120000.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689206400.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689292800.0,
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
          "cost": 2.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689379200.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689465600.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689552000.0,
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
          "cost": 0.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689638400.0,
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
          "cost": 8.0
        },
        {
          "name": "Audio models",
          "cost": 0.0
        }
      ]
    },
    {
      "timestamp": 1689724800.0,
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
          "cost": 0.0
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

@app.route("/v1/models")
@app.route("/models")
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

@app.route("/v1/providers")
@app.route("/providers")
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

@app.errorhandler(404)
def page_not_found(e):
    return jsonify({
        "error": {
            "message": f"Invalid URL ({request.method} /)",
            "type": "invalid_request_error",
            "param": None,
            "code": None
        }
    }), 404

@app.errorhandler(500)
def internal_server_error(e):
    return jsonify({
        "error": {
            "message": "Something went wrong on our end",
            "type": "internal_server_error",
            "param": None,
            "code": None
        }
    }), 500

@app.errorhandler(415)
def unsupported_media_type(e):
    return jsonify({
        "error": {
            "message": "Unsupported media type",
            "type": "unsupported_media_type",
            "param": None,
            "code": None
        }
    }), 415

if __name__ == '__main__':
    site_config = {
        'host': '0.0.0.0',
        'port': 1337,
        'debug': False
    }
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    print(f"Running on http://127.0.0.1:{site_config['port']}")
    print(f"Running on http://{ip_address}:{site_config['port']}")
    server = pywsgi.WSGIServer(('0.0.0.0', site_config['port']), app)
    server.serve_forever()
