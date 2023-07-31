import g4f
from fp.fp import FreeProxy

proxy = FreeProxy(country_id=['US', 'GB', 'FL'], timeout=0.5, rand=True, https=True).get()
# Set with provider
stream = False
print(proxy)
response = g4f.ChatCompletion.create(model='claude-2', provider=g4f.Provider.ClaudeAI, messages=[
                                     {"role": "user", "content": "hello"}], stream=False)

if stream:
    for message in response:
        print(message)
else:
    print(response)