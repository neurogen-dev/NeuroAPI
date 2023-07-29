import g4f
from fp.fp import FreeProxy

proxy = FreeProxy(country_id=['US', 'GB '], timeout=0.5, rand=True).get()
# Set with provider
stream = True

response = g4f.ChatCompletion.create(model='bing', provider=g4f.Provider.Bing, messages=[
                                     {"role": "user", "content": "hello"}], stream=stream, proxy=proxy)

if stream:
    for message in response:
        print(message)
else:
    print(response)