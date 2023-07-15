import time
import json
import random
import time
from gevent import pywsgi
import socket
from flask import Flask, request, Response, jsonify
from flask_cors import CORS

from g4f import ChatCompletion, Provider

app = Flask(__name__)
CORS(app)

@app.route("/v1/models", methods=['GET'])
def models():
    data = [
        {
            "id": "gpt-3.5-turbo",
            "object": "model",
            "owned_by": "organization-owner",
            "permission": []
        }
    ]
    return {'data': data, 'object': 'list'}
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
def billing_subscription():
    return jsonify({
  "id": "sub_0947613321",
  "plan": "Enterprise",
  "status": "active",
  "start_date": "2023-01-01",
  "end_date": "null",
  "current_period_start": "2023-01-01",
  "current_period_end": "null",
  "trial_start": "null",
  "trial_end": "null",
  "cancel_at_period_end": False,
  "canceled_at": "null",
  "created_at": "2023-01-01",
  "updated_at": "2023-01-01"
})

@app.after_request
def after_request(response):
    origin = request.headers.get('Origin')
    response.headers.add('Access-Control-Allow-Origin', origin)
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE')
    response.headers.add('Access-Control-Allow-Headers', '*')
    response.headers.add('Access-Control-Allow-Credentials', 'true')
    return response

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
