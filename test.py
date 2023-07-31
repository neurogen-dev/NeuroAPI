import g4f
from fp.fp import FreeProxy

proxy = FreeProxy(country_id=['US', 'GB '], timeout=0.5, rand=True).get()
# Set with provider
stream = False

response = g4f.ChatCompletion.create(model='gpt-3.5-turbo', provider=g4f.Provider.Vercel, messages=[
                                     {"role": "user", "content": "hello"}], stream=False)

if stream:
    for message in response:
        print(message)
else:
    print(response)