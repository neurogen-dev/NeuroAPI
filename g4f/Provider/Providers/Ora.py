import os, requests
from ...typing import sha256, Dict, get_type_hints

url = 'https://ora.ai'
model = ['gpt-3.5-turbo']
supports_stream = False
needs_auth = False
working = True

def _create_completion(model: str, messages: list, stream: bool, **kwargs):
    conversation = 'This is a conversation between a human and a language model. The language model should always respond as the assistant, referring to the past history of messages if needed.\n'
    
    for message in messages:
        conversation += '%s: %s\n' % (message['role'], message['content'])
    
    conversation += 'assistant: '
    headers = {
        'authority': 'ora.ai',
        'accept': '*/*',
        'accept-language': 'en,fr-FR;q=0.9,fr;q=0.8,es-ES;q=0.7,es;q=0.6,en-US;q=0.5,am;q=0.4,de;q=0.3',
        'cache-control': 'no-cache',
        'content-type': 'application/json',
        'origin': 'https://ora.ai',
        'pragma': 'no-cache',
        'referer': 'https://ora.ai/chat/',
        'sec-ch-ua': '"Google Chrome";v="113", "Chromium";v="113", "Not-A.Brand";v="24"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36',
        'Cookie': '__stripe_mid=a56e924b-2fc8-4a5a-bd45-2a9b2f90c821ae1cc2; __Host-next-auth.csrf-token=18b2d76af264f3be487542eee9a7169c1e09cc60d6e58d01a2dc7ca9d5b2b6ab%7C8f0868e295fb539fe31adc831c97646c1d5558c476d68290aa9641d494ac2928; __Secure-next-auth.callback-url=https%3A%2F%2Fora.ai%2Fsignup; __cf_bm=8GN7_fyYZFVE6pluSM6fwRsEvR5tLdHZV6B6PtPabw0-1689571388-0-AaYsV9KRozJtjoHYS5CPsXXv+GfFwwlPQBII/4hgm95TXKBf/S2yFlSe7SxRhq3krQ==; __Secure-next-auth.session-token=eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..TgC127Dg55n8FpBo.sLYCC12VYB6gIHf78l70H5wpwv8VERxP2U_YDIQ1j4tTl15_4Op1660qlEQ0jrWT0oPyDOyp6dD-IuQwPszvZF3QkhZkfTm85zeaBnYMBYRUmosJrY3RdXWyxpFN1ft3Eqqu-aJfiiBDuC_gyTzu0rDlu8AIdvLZK1BB7n-fjCO3Pdga8Di4Jb7FbgCm_8eQ9jPbj6HX2bE08JF6Kdl_TNexO3I_zS5QSuqIw2HtPjCCMffcKhcBmL4Dk6M1JidI3CXyljhJRHyc3gUtVgDIWY2b1ub53w51FtG8pbFQxF-Hf5k6TB9cJTnmdJHfGUFfMadST-9aUEfNDzvQvR7eehPg59a6f42W-3b6RQWxxfar7nW6egfcQLXb96hI1U58VF9VYp8YOg94BgtCh2RPp0jQmgVbS9Yrw65BT_FIym0yag21uexvSZsOA2iyzGOFe5Ot1cXF0VOgwXT0UKpnhH1GQX5eh-PNXsn5IoDABDKLbRy2o7q5RZJjgoDj-UhXBDtAkaBeo7BqUVtUKxNxnPvmhX-caeVVEy98zicIo6dl9GIPdmXglY6YYDxkW0XHP8r-QFaSdw6_YRZY3ilWbydYAsizGlDSFOBuJTs0MGVW7dTLAi0Q7f--za_eOEa_j7NH-UVT0nXIN8wkFKZp_vxo3dw.39pQCYhCDGBbvwBGrL1ntw'
    }

    json_data = {
        'chatbotId': 'c38a3119-3ee3-474b-b3a6-9f811e291325',
        'input': conversation,
        'userId': 'c26561a7-7755-485a-8ad3-38071f0d42f0',
        'provider': 'OPEN_AI',
        'config': False,
        'includeHistory': False
    }

    response = requests.post('https://ora.ai/api/conversation', 
                            headers=headers, json=json_data)
    
    yield response.json()['response']

params = f'g4f.Providers.{os.path.basename(__file__)[:-3]} supports: ' + \
    '(%s)' % ', '.join([f"{name}: {get_type_hints(_create_completion)[name].__name__}" for name in _create_completion.__code__.co_varnames[:_create_completion.__code__.co_argcount]])