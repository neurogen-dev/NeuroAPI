import g4f
from fp.fp import FreeProxy

proxy = FreeProxy(country_id=['US'], timeout=0.5, rand=True).get()
# Set with provider
stream = False
print(proxy)
response = g4f.ChatCompletion.create(model='text-davinci-003', provider=g4f.Provider.Vercel, messages=[
                                     {"role": "user", "content": "hello"}], stream=False, proxy=proxy)

if stream:
    for message in response:
        print(message)
else:
    print(response)