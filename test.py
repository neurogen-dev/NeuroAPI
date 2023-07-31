import g4f
from fp.fp import FreeProxy

proxy = FreeProxy(country_id=['US', 'GB '], timeout=0.5, rand=True).get()
# Set with provider
stream = False

response = g4f.ChatCompletion.create(model='ada', provider=g4f.Provider.PurGPT, messages=[
                                     {"role": "user", "content": "hello"}], stream=stream)

if stream:
    for message in response:
        print(message)
else:
    print(response)