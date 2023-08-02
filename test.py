import g4f
from fp.fp import FreeProxy
import os, requests
from g4f.typing import sha256, Dict, get_type_hints
import json

proxy = FreeProxy(country_id=['US'], timeout=0.5, rand=True).get()
stream = False
print(proxy)
response = g4f.ChatCompletion.create(model='gpt-3.5-turbo-16k', provider=g4f.Provider.CharFree, messages=[
                                    {"role": "user", "content": "hello"}], stream=stream)



if stream:
    for message in response:
        print(message)
else:
    print(response)