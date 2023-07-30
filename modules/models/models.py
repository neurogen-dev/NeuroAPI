from __future__ import annotations

import logging
import json
import commentjson as cjson
import requests

import colorama


from ..presets import *
from ..index_func import *
from ..utils import *
from .. import shared
from ..config import retrieve_proxy, usage_limit
from modules import config
from .base_model import BaseLLMModel, ModelType


class OpenAIClient(BaseLLMModel):
    def __init__(
        self,
        model_name,
        api_key,
        system_prompt=INITIAL_SYSTEM_PROMPT,
        temperature=1.0,
        top_p=1.0,
        user_name=""
    ) -> None:
        super().__init__(
            model_name=model_name,
            temperature=temperature,
            top_p=top_p,
            system_prompt=system_prompt,
            user=user_name
        )
        with open("config.json", "r") as f:
            self.configuration_json = cjson.load(f)
        self.api_key = api_key
        self.need_api_key = True
        self._refresh_header()

    def get_answer_stream_iter(self):
        response = self._get_response(stream=True)
        if response is not None:
            iter = self._decode_chat_response(response)
            partial_text = ""
            for i in iter:
                partial_text += i
                yield partial_text
        else:
            yield STANDARD_ERROR_MSG + GENERAL_ERROR_MSG


    def get_answer_at_once(self):
        response = self._get_response()
        response = json.loads(response.text)
        content = response["choices"][0]["message"]["content"]
        total_token_count = response["usage"]["total_tokens"]
        return content, total_token_count

    def count_token(self, user_input):
        input_token_count = count_token(construct_user(user_input))
        if self.system_prompt is not None and len(self.all_token_counts) == 0:
            system_prompt_token_count = count_token(
                construct_system(self.system_prompt)
            )
            return input_token_count + system_prompt_token_count
        return input_token_count

    def billing_info(self):
        try:
            curr_time = datetime.datetime.now()
            last_day_of_month = get_last_day_of_month(
                curr_time).strftime("%Y-%m-%d")
            first_day_of_month = curr_time.replace(day=1).strftime("%Y-%m-%d")
            usage_url = f"{shared.state.usage_api_url}?start_date={first_day_of_month}&end_date={last_day_of_month}"
            try:
                usage_data = self._get_billing_data(usage_url)
            except Exception as e:
                None
            rounded_usage = round(usage_data["total_usage"] / 100, 5)
            usage_percent = round(usage_data["total_usage"] / usage_limit, 2)
            return get_html("billing_info.html").format(
                    label = "Ежемесячное использование",
                    usage_percent = usage_percent,
                    rounded_usage = rounded_usage,
                    usage_limit = usage_limit
                )
        except requests.exceptions.ConnectTimeout:
            None
        except requests.exceptions.ReadTimeout:
            None
        except Exception as e:
            None

    def set_token_upper_limit(self, new_upper_limit):
        pass

    @shared.state.switching_api_key  # 在不开启多账号模式的时候，这个装饰器不会起作用
    def _get_response(self, stream=False):
        headers = self._get_headers()
        history = self._get_history()
        payload = self._get_payload(history, stream)
        shared.state.completion_url = self._get_api_url()
        logging.info(f"Используется API URL: {shared.state.completion_url}")
        with retrieve_proxy():
            response = self._make_request(headers, payload, stream)
        return response

    def _get_api_url(self):
        if "chimera" in self.model_name: 
            url = "https://chimeragpt.adventblocks.cc/api/v1/chat/completions"
        elif "bing" in self.model_name:
            url = "https://purgpt.xyz/v1/bing"
        elif "chatty" in self.model_name:
            url = "https://chattyapi.tech/v1/chat/completions"
        else:
            url = "http://127.0.0.1:1337/v1/chat/completions"
        return url
      
    def _get_headers(self):
        if self.model_name == "bing":
            purgpt_api_key = self.configuration_json["purgpt_api_key"]
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {purgpt_api_key}",
            }
        elif "chatty" in self.model_name:
            chatty_api_key = self.configuration_json["chatty_api_key"]
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {chatty_api_key}",
            }
        else:
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}",
            }
        return headers
         
    def _get_history(self):
        system_prompt = self.system_prompt
        history = self.history
        logging.debug(colorama.Fore.YELLOW + f"{history}" + colorama.Fore.RESET)
        if system_prompt is not None:
            history = [construct_system(system_prompt), *history]
        return history

    def _get_payload(self, history, stream): 
        model_names = {
            'gpt-4-chimera-api': 'gpt-4',
            'gpt-4-0314-chimera-api': 'gpt-4-0314',
            'llama-2-70b-chat-chimera-api': 'llama-2-70b-chat',
            'gpt-3.5-turbo-16k-chimera-api': 'gpt-3.5-turbo-16k',
            'gpt-3.5-turbo-16k-chatty-api': 'gpt-3.5-turbo-16k',
            'gpt-4-chatty-api': 'gpt-4',
            'gpt-4-32k-chatty-api': 'gpt-4-32k'
        }
        model = model_names.get(self.model_name, self.model_name)
        payload = {
            "model": model,
            "messages": history,
            "temperature": self.temperature,
            "top_p": self.top_p,
            "n": self.n_choices,
            "stream": stream,
            "presence_penalty": self.presence_penalty,
            "frequency_penalty": self.frequency_penalty,
        }
        if self.max_generation_token is not None:
            payload["max_tokens"] = self.max_generation_token
        if self.stop_sequence is not None:
            payload["stop"] = self.stop_sequence
        if self.logit_bias is not None:
            payload["logit_bias"] = self.logit_bias
        if self.user_identifier:
            payload["user"] = self.user_identifier
        return payload

    def _make_request(self, headers, payload, stream):
        if stream:
            timeout = TIMEOUT_STREAMING
        else:
            timeout = TIMEOUT_ALL
        try:
            response = requests.post(
                shared.state.completion_url,
                headers=headers,
                json=payload,
                stream=stream,
                timeout=timeout,
            )
        except:
            return None
        return response

    def _refresh_header(self):
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}",
        }

    def _get_billing_data(self, billing_url):
        with retrieve_proxy():
            response = requests.get(
                billing_url,
                headers=self.headers,
                timeout=TIMEOUT_ALL,
            )
        if response.status_code == 200:
            data = response.json()
            return data
        else:
            raise Exception(f"API request failed with status code {response.status_code}: {response.text}")

    def _decode_chat_response(self, response):
        error_msg = ""
        for chunk in response.iter_lines():
            if chunk:
                chunk = chunk.decode()
                chunk_length = len(chunk)
                try:
                    chunk = json.loads(chunk[6:])
                except json.JSONDecodeError:
                    error_msg += chunk
                    continue
                if chunk_length > 6 and "delta" in chunk["choices"][0]:
                    if chunk["choices"][0]["finish_reason"] == "stop":
                        break
                    try:
                        yield chunk["choices"][0]["delta"]["content"]
                    except Exception as e:
                        continue
        if error_msg:
            yield "Провайдер API ответил ошибкой: " + error_msg

    def set_key(self, new_access_key):
        ret = super().set_key(new_access_key)
        self._refresh_header()
        return ret

def get_model(
    model_name,
    lora_model_path=None,
    access_key=None,
    temperature=None,
    top_p=None,
    system_prompt=None,
    user_name=""
) -> BaseLLMModel:
    msg = "Модель установлена на: " + f" {model_name}"
    model_type = ModelType.get_type(model_name)
    lora_selector_visibility = False
    lora_choices = []
    dont_change_lora_selector = False
    if model_type != ModelType.OpenAI:
        config.local_embedding = True
    # del current_model.model
    model = None
    chatbot = gr.Chatbot.update(label=model_name)
    try:
        if model_type == ModelType.OpenAI:
            logging.info(f"Загрузка модели OpenAI: {model_name}")
            model = OpenAIClient(
                model_name=model_name,
                api_key=access_key,
                system_prompt=system_prompt,
                temperature=temperature,
                top_p=top_p,
                user_name=user_name,
            )
        elif model_type == ModelType.Unknown:
            logging.info(f"正在加载OpenAI模型: {model_name}")
            model = OpenAIClient(
                model_name=model_name,
                api_key=access_key,
                system_prompt=system_prompt,
                temperature=temperature,
                top_p=top_p,
                user_name=user_name,
            )
        logging.info(msg)
    except Exception as e:
        import traceback
        traceback.print_exc()
        msg = f"{STANDARD_ERROR_MSG}: {e}"
    if dont_change_lora_selector:
        return model, msg, chatbot
    else:
        return model, msg, chatbot, gr.Dropdown.update(choices=lora_choices, visible=lora_selector_visibility)


if __name__ == "__main__":
    with open("config.json", "r") as f:
        openai_api_key = cjson.load(f)["openai_api_key"]
    # set logging level to debug
    logging.basicConfig(level=logging.DEBUG)
    # client = ModelManager(model_name="gpt-3.5-turbo", access_key=openai_api_key)
    client = get_model(model_name="chatglm-6b-int4")
    chatbot = []
    stream = False
    # 测试账单功能
    logging.info(colorama.Back.GREEN + "测试账单功能" + colorama.Back.RESET)
    logging.info(client.billing_info())
    # 测试问答
    logging.info(colorama.Back.GREEN + "测试问答" + colorama.Back.RESET)
    question = "巴黎是中国的首都吗？"
    for i in client.predict(inputs=question, chatbot=chatbot, stream=stream):
        logging.info(i)
    logging.info(f"测试问答后history : {client.history}")
    # 测试记忆力
    logging.info(colorama.Back.GREEN + "测试记忆力" + colorama.Back.RESET)
    question = "我刚刚问了你什么问题？"
    for i in client.predict(inputs=question, chatbot=chatbot, stream=stream):
        logging.info(i)
    logging.info(f"测试记忆力后history : {client.history}")
    # 测试重试功能
    logging.info(colorama.Back.GREEN + "测试重试功能" + colorama.Back.RESET)
    for i in client.retry(chatbot=chatbot, stream=stream):
        logging.info(i)
    logging.info(f"重试后history : {client.history}")
    # # 测试总结功能
    # print(colorama.Back.GREEN + "测试总结功能" + colorama.Back.RESET)
    # chatbot, msg = client.reduce_token_size(chatbot=chatbot)
    # print(chatbot, msg)
    # print(f"总结后history: {client.history}")
