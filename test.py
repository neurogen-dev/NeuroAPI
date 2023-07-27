import g4f

# Set with provider
stream = True
response = g4f.ChatCompletion.create(model='bing', provider=g4f.Provider.BingHuan, messages=[
                                     {"role": "user", "content": "hello"}], stream=stream)

if stream:
    for message in response:
        print(message)
else:
    print(response)