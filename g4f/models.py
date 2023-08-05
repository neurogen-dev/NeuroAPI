import random
import requests
from g4f import Provider


class Model:
    class model:
        name: str
        base_provider: str
        best_provider: str

    class gpt_35_turbo:

        # Function to get the status response from the API
        @staticmethod
        def get_status_response():
            status_url = 'https://provider.neurochat-gpt.ru/v1/status'
            response = requests.get(status_url)
            return response.json()

        # Get the providers with status 'Active'
        status_response = get_status_response()
        active_providers = [
            provider_info['provider']
            for provider_info in status_response['data']
            if any(
                model_info.get('gpt-3.5-turbo', {}).get('status') == 'Active'
                for model_info in provider_info.get('model', [])
            )
        ]

        random_provider = random.choice(active_providers)

        name: str = 'gpt-3.5-turbo'
        base_provider: str = 'openai'
        # Generate the 'best_providers' list with active providers
        best_provider: Provider.Provider = getattr(Provider, random_provider)
        best_providers: list = [getattr(Provider, active_provider) for active_provider in active_providers]

    class gpt_35_turbo_0613:
        name: str = 'gpt-3.5-turbo-0613'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Zeabur
        #best_provider: Provider.Provider = random.choice([Provider.Zeabur])
        best_providers: list = [Provider.Zeabur]
        

    class gpt_35_turbo_16k_0613:
        name: str = 'gpt-3.5-turbo-16k-0613'
        base_provider: str = 'openai'
        #best_provider: Provider.Provider = Provider.Easychat
        best_provider: Provider.Provider = Provider.Zeabur
        best_providers: list = [Provider.Zeabur]

    class gpt_35_turbo_16k:

        # Function to get the status response from the API
        @staticmethod
        def get_status_response():
            status_url = 'https://provider.neurochat-gpt.ru/v1/status'
            response = requests.get(status_url)
            return response.json()

        # Get the providers with status 'Active'
        status_response = get_status_response()
        active_providers = [
            provider_info['provider']
            for provider_info in status_response['data']
            if any(
                model_info.get('gpt-3.5-turbo-16k', {}).get('status') == 'Active'
                for model_info in provider_info.get('model', [])
            )
        ]

        if not active_providers:
            active_providers = ['EasyChat']

        random_provider = random.choice(active_providers)

        name: str = 'gpt-3.5-turbo-16k'
        base_provider: str = 'openai'
        # Generate the 'best_providers' list with active providers
        best_provider: Provider.Provider = getattr(Provider, random_provider)
        best_providers: list = [getattr(Provider, active_provider) for active_provider in active_providers]


    class gpt_4:
        name: str = 'gpt-4'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Chatty
        best_providers: list = [Provider.Chatty]
        
    class gpt_4_standart:
        name: str = 'gpt-4-standart'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.DfeHub
        best_providers: list = [Provider.DfeHub]
    
    class gpt_4_0613:
        name: str = 'gpt-4-0613'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Chatty
        best_providers: list = [Provider.Chatty]

    class gpt_4_32k:
        name: str = 'gpt-4-32k'
        base_provider: str = 'reversed'
        best_provider: Provider.Provider = Provider.Chatty
        best_providers: list = [Provider.Chatty]

    class claude_2:
        name: str = 'claude-2'
        base_provider: str = 'anthropic'
        best_provider: Provider.Provider = Provider.ClaudeAI

    class code_cushman_001:
        name: str = 'code-cushman-001'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class code_davinci_002:
        name: str = 'code-davinci-002'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class text_ada_001:
        name: str = 'text-ada-001'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class text_babbage_001:
        name: str = 'text-babbage-001'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class text_curie_001:
        name: str = 'text-curie-001'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class text_davinci_002:
        name: str = 'text-davinci-002'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class text_davinci_003:
        name: str = 'text-davinci-003'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.Vercel

    class ada:
        name: str = 'ada'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.PurGPT
        
    class palm:
        name: str = 'palm2'
        base_provider: str = 'google'
        best_provider: Provider.Provider = Provider.Bard
        
    class llama_13b:
        name: str = 'llama-13b'
        base_provider: str = 'huggingface'
        best_provider: Provider.Provider = Provider.H2o

    class llama_2_70b_chat:
        name: str = 'llama-2-70b-chat'
        base_provider: str = 'huggingface'
        best_provider: Provider.Provider = Provider.Chimera
        
    class bing:
        name: str = 'bing'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.BingHuan
    
    class gpt_35_turbo_16k_purgpt_api:
        name: str = 'gpt-3.5-turbo-16k-purgpt-api'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.PurGPT

    class gpt_35_turbo_purgpt_api:
        name: str = 'gpt-3.5-turbo-purgpt-api'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.PurGPT

    class text_davinci_003_purgpt_api:
        name: str = 'text-davinci-003-purgpt-api'
        base_provider: str = 'openai'
        best_provider: Provider.Provider = Provider.PurGPT
    
class ModelUtils:
    convert: dict = {
        'gpt-3.5-turbo': Model.gpt_35_turbo,
        'gpt-3.5-turbo-0613': Model.gpt_35_turbo_0613,
        'gpt-4': Model.gpt_4,
        'gpt-4-standart': Model.gpt_4_standart,
        'gpt-4-0613': Model.gpt_4_0613,
        'gpt-3.5-turbo-16k': Model.gpt_35_turbo_16k,
        'gpt-3.5-turbo-16k-0613': Model.gpt_35_turbo_16k_0613,
        
        'claude-2': Model.claude_2,
        
        'code-cushman-001': Model.code_cushman_001,
        'code-davinci-002': Model.code_davinci_002,
        
        'text-ada-001': Model.text_ada_001,
        'text-babbage-001': Model.text_babbage_001,
        'text-curie-001': Model.text_curie_001,
        'text-davinci-002': Model.text_davinci_002,
        'text-davinci-003': Model.text_davinci_003,

        'ada': Model.ada,
        
        'palm2': Model.palm,
        'palm': Model.palm,
        'google': Model.palm,
        'google-bard': Model.palm,
        'google-palm': Model.palm,
        'bard': Model.palm,
        
        'llama-13b': Model.llama_13b,
        'llama-2-70b-chat': Model.llama_2_70b_chat,
        'bing': Model.bing,

        'gpt-3.5-turbo-16k-purgpt-api': Model.gpt_35_turbo_16k_purgpt_api,
        'gpt-3.5-turbo-purgpt-api': Model.gpt_35_turbo_purgpt_api,
        'text-davinci-003-purgpt-api': Model.text_davinci_003_purgpt_api,
    }
