import os, uuid, requests
from ...typing import sha256, Dict, get_type_hints

url = 'https://liaobots.com'
model = ['gpt-3.5-turbo', 'gpt-4']
supports_stream = True
needs_auth = True

models = {
    'gpt-4': {
        "id":"gpt-4",
        "name":"GPT-4",
        "maxLength":24000,
        "tokenLimit":8000
    },
    'gpt-3.5-turbo': {
        "id":"gpt-3.5-turbo",
        "name":"GPT-3.5",
        "maxLength":12000,
        "tokenLimit":4000
    },
     'gpt-3.5-turbo-16k': {
        "id":"gpt-3.5-turbo-16k",
        "name":"GPT-3.5",
        "maxLength":48000,
        "tokenLimit":16000
    },
}

def get_key(n):
    with open('liaobotskeys.txt', 'r') as f:
        keys = f.readlines()
    while keys[get_key.counter - 1].startswith('fd'):
        get_key.counter += 1
    if n:
        keys[get_key.counter - 1] = f'fd-{keys[get_key.counter - 1]}'
        with open('liaobotskeys.txt', 'w') as file:
            file.writelines(keys)
        get_key.counter += 1
        
    key = keys[get_key.counter - 1].strip()
    return key

get_key.counter = 1

def _create_completion(model: str, messages: list, stream: bool, **kwargs):
  unsuccessful = False
  while True:
      headers = {
          'authority': 'liaobots.com',
          'content-type': 'application/json',
          'origin': 'https://liaobots.com',
          'referer': 'https://liaobots.com/',
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36',
          'x-auth-code': get_key(unsuccessful)
      }
  
      json_data = {
          'conversationId': str(uuid.uuid4()),
          'model': models[model],
          'messages': messages,
          'auth': get_key(unsuccessful),
          'key': '',
          'prompt': "You are ChatGPT, a large language model trained by OpenAI. Follow the user's instructions carefully. Respond using markdown.",
      }

    
      response = requests.post('https://liaobots.com/api/chat', 
                               headers=headers, json=json_data, stream=True)
  
      token = ''
      error_detected = False
      counter = 0
    
      for chunk in response.iter_content(chunk_size=2046):
          token += chunk.decode()
          counter += 1

          # Buffer length surpasses 'Error' length, can output chunks
          #if len(token) > len('Error'):
          #    print(token)
          #    token = ''
          if token == 'Error' and counter == 1:  
              error_detected = True
          else:
            token = ''
            yield (chunk.decode('utf-8'))

      if token == 'Error' and error_detected:
          print("The server returned an Error.")
          unsuccessful = True
      else:
          print(token)  # print any remainder from the buffer
          break

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])