import g4f

# Set with provider
stream = False
response = g4f.ChatCompletion.create(model='claude-2', provider=g4f.Provider.ClaudeAI, messages=[
                                     {"role": "user", "content": "hello"}], stream=stream)

if stream:
    for message in response:
        print(message)
else:
    print(response)