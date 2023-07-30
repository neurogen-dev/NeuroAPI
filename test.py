# import g4f
# from fp.fp import FreeProxy

# proxy = FreeProxy(country_id=['US', 'GB '], timeout=0.5, rand=True).get()
# # Set with provider
# stream = True

# response = g4f.ChatCompletion.create(model='bing', provider=g4f.Provider.Bing, messages=[
                                     # {"role": "user", "content": "hello"}], stream=stream, proxy=proxy)

# if stream:
    # for message in response:
        # print(message)
# else:
    # print(response)
    
import openai

openai.api_key = "purgpt-b2vrs9w13oiyf14a7v4lt"
openai.api_base = "https://purgpt.xyz/v1/bing"

response = openai.ChatCompletion.create(
    model='gpt-3.5-turbo',
    messages=[
        {'role': 'user', 'content': "Hello"},
    ]
)

print(response)