import os
import g4f
import json
import time
import pytz
from datetime import datetime
import concurrent.futures
import asyncio
from g4f import ChatCompletion
from fp.fp import FreeProxy
import threading  
import socket  
from auto_proxy import get_random_proxy, update_working_proxies

def process_provider(provider_name, model_name):
    try:
        p = getattr(g4f.Provider, provider_name)
        provider_status = {
            "provider": provider_name,
            "model": model_name,
            "url": p.url,
            "status": ""
        }

        # Проверяем только модель 'gpt-3.5-turbo' для провайдеров Wewordle и Qidinam
        if provider_name in ['Wewordle', 'Qidinam', 'DeepAi', 'GetGpt', 'Yqcloud', 'WewordleApple'] and model_name != 'gpt-3.5-turbo':
            provider_status['status'] = 'Inactive'
            print(f"{provider_name} with {model_name} skipped")
            return provider_status

        try:
            proxy = get_random_proxy().decode("utf-8")
            formatted_proxy = f'https://{proxy}'
            
            response = ChatCompletion.create(model=model_name, provider=p,
                                                 messages=[{"role": "user", "content": "Say 'Hello World!'"}], stream=False)
            if any(word in response for word in ['Hello World', 'Hello', 'hello', 'world']):
                provider_status['status'] = 'Active'
                print(f"{provider_name} with {model_name} say: {response}")
            else:
                provider_status['status'] = 'Inactive'
                print(f"{provider_name} with {model_name} say: Inactive")
        except Exception as e:
            provider_status['status'] = 'Inactive'
            print(f"{provider_name} with {model_name} say: Error")

        return provider_status
    except:
        return None

def main():
    while True:
        models = [model for model in g4f.models.ModelUtils.convert if model.startswith('gpt-') or model.startswith('claude') or model.startswith('text-')]
        providers = [provider for provider in dir(g4f.Provider) if not provider.startswith('__')]

        status = {'data': []}
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = []
            for provider_name in providers:
                for model_name in models:
                    future = executor.submit(process_provider, provider_name, model_name)
                    futures.append(future)

            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result is not None and result['status'] == 'Active':
                    status['data'].append(result)

        print(status)
        status['key'] = "test"
        tz = pytz.timezone('Asia/Shanghai')
        now = datetime.now(tz)
        print(now)
        status['time'] = now.strftime("%Y-%m-%d %H:%M:%S")

        # Save the status data to a JSON file only if there are active providers
        if status['data']:
            with open('status.json', 'w') as f:
                json.dump(status, f)

        # Pause for 10 minutes before starting the next cycle
        time.sleep(600)

if __name__ == "__main__":
    main()