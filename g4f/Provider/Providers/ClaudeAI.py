import requests
import uuid
import json
import os
from ...typing import sha256, Dict, get_type_hints

url = 'https://claude.ai/chats'
supports_stream = True
needs_auth = False
working = True
model = ['claude-2']

cookies = 'sessionKey=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; intercom-device-id-lupk8zyo=537137f7-d63c-4597-b612-2f5f32615a8b; intercom-session-lupk8zyo=Vk9kQjZpckdiRzlyd2lqSW4rR1BOSFNNNzJiWElwcHI2bVByUXZhNzUrVXN4MVd1OEowR0tDTVh1STlmcnN6bS0tVFZ1bWdpNkdMNzRyWTQvWTNhaDBRUT09--d354a97da2b9a18785b9dbb03eb392dda456cdf0; __cf_bm=3j8nLojJCpR4QHwtF2UpgqvA0VOXGOiQIYzm0FWs9xA-1689490831-0-AVKf3/AErZz0g47J30F/c+toy4Zk7uP+L5HmhTjBpDzNhK1cF5HuGq7NLvGAKbQ1MYvBiWQkDGWoPZdLJNTCTpY='
user = '55a415d1-0264-4d52-a7ec-2adc2e050806'
h1 = {
  'Authority': 'claude.ai',
  'Scheme': 'https',
  'Accept': '*/*',
  'Accept-Encoding': 'gzip, deflate, br',
  'Accept-Language': 'en-US,en;q=0.5',
  'Content-Type': 'application/json',
  'Cookie': cookies,
  'Origin': 'https://claude.ai',
  'Referer': 'https://claude.ai/chats',
  'Sec-Ch-Ua': '"Not.A/Brand";v="8", "Chromium";v="114", "Google Chrome";v="114"',
  'Sec-Ch-Ua-Mobile': '?0',
  'Sec-Ch-Ua-Platform': '"Windows"',
  'Sec-Fetch-Dest': 'empty',
  'Sec-Fetch-Mode': 'cors',
  'Sec-Fetch-Site': 'same-origin',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
}



def _create_completion(model: str, messages: list, stream: bool, **kwargs):
  conversation = 'This is a conversation between a human and a language model. The language model should always respond as the assistant, referring to the past history of messages if needed.\n'
  for message in messages:
    conversation += '%s: %s\n' % (message['role'], message['content'])
  conversation += 'assistant: '
  _uuid = str(uuid.uuid4())
  session = requests.Session()
  r = session.post("https://claude.ai/api/organizations/"+user+"/chat_conversations",data=json.dumps({"uuid":_uuid ,"name": ""}),headers=h1)
  r = session.post("https://claude.ai/api/append_message",data=json.dumps({
    "completion": {
      "prompt": conversation,
      "timezone": "Asia/Shanghai",
      "model": "claude-2",
      "incremental": True
    },
    "organization_uuid": user,
    "conversation_uuid": _uuid,
    "text": conversation,
    "attachments": []
  }),headers=h1,stream=True)
  r.encoding='utf-8'
  text = ''
  for line in r.text.split('\n'):
    if line.startswith('data:'):
        line = line[5:] 
        data = json.loads(line) 
        try:
           yield str(data['completion'].encode('utf-8').decode('utf-8') )
        except:
           pass
  r = session.delete("https://claude.ai/api/organizations/"+user+"/chat_conversations/"+_uuid,headers=h1)
  


params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])
