import os
from pathlib import Path
import gradio as gr
import requests
import json

VERSION = "v 1.5.4"

CHATGLM_MODEL = None
CHATGLM_TOKENIZER = None
LLAMA_MODEL = None
LLAMA_INFERENCER = None

# ChatGPT 设置

INITIAL_SYSTEM_PROMPT = "You are a helpful assistant. You follow all of the user's instructions and answer all of their questions without going out of your way to answer them. Respond using markdown."
API_HOST = "https://neuroapi.host"
COMPLETION_URL = "https://neuroapi.host/v1/chat/completions"
BALANCE_API_URL="https://neuroapi.host/v1/dashboard/billing/credit_grants"
USAGE_API_URL="https://neuroapi.host/v1/dashboard/billing/usage"
HISTORY_DIR = Path("history")
HISTORY_DIR = "history"
TEMPLATES_DIR = "templates"

# 错误信息
STANDARD_ERROR_MSG = "☹️Произошла ошибка:"# Стандартный префикс для сообщений об ошибках 
GENERAL_ERROR_MSG = "Произошла ошибка при получении диалога, пожалуйста, проверьте лог бэкенда"
ERROR_RETRIEVE_MSG = "Пожалуйста, проверьте свое интернет-соединение или валидность API-Key."
CONNECTION_TIMEOUT_MSG = "Тайм-аут соединения, не удалось получить диалог."# Тайм-аут соединения 
READ_TIMEOUT_MSG = "Тайм-аут чтения, не удалось получить диалог."# Тайм-аут чтения 
PROXY_ERROR_MSG = "Ошибка прокси, не удалось получить диалог."# Ошибка прокси 
SSL_ERROR_PROMPT = "Ошибка SSL, не удалось получить диалог."# Ошибка SSL 
NO_APIKEY_MSG = "API key пуст, пожалуйста, проверьте, правильно ли он введен."# Длина API key меньше 51 бита 
NO_INPUT_MSG = "Пожалуйста, введите содержание диалога."# Не введено содержание диалога 
BILLING_NOT_APPLICABLE_MSG = "Информация о биллинге не применима"# Информация о биллинге, возвращаемая локально запущенной моделью

TIMEOUT_STREAMING = 240 # Время ожидания для потокового диалога 
TIMEOUT_ALL = 400 # Время ожидания для непотокового диалога 
ENABLE_STREAMING_OPTION = True # Включить ли флажок для выбора отображения ответа в режиме реального времени 
HIDE_MY_KEY = False # Если вы хотите скрыть свой API ключ в UI, установите это значение в True 
CONCURRENT_COUNT = 500 # Количество пользователей, которые могут использовать одновременно

SIM_K = 5
INDEX_QUERY_TEMPRATURE = 1.0

CHUANHU_TITLE = "NeuroGPT " + VERSION

CHUANHU_DESCRIPTION = "[ℹ️ Телеграм канал проекта](https://t.me/neurogen_news) <br /> [💰 Поддержать автора](https://boosty.to/neurogen) </br>"

ONLINE_MODELS = [
    'gpt-3.5-turbo',
    'gpt-3.5-turbo',
    'gpt-3.5-turbo-0613',
    'gpt-3.5-turbo-16k',
    'gpt-3.5-turbo-16k-0613',
    'gpt-4',
    'gpt-4-0613',
    'chat-agent-beta',
]

NAGA_MODELS = [
    'naga-gpt-3.5-turbo-16k',
    'naga-gpt-4',
    'naga-llama-2-70b-chat',
    #'naga-claude-2'
    #'naga-text-davinci-003',
]

CHATTY_MODELS = [
    'chatty-gpt-3.5-turbo-16k',
    'chatty-gpt-4',
    #'gpt-4-32k-chatty-api',
]


PURGPT_MODELS = [
    'purgpt-gpt-3.5-turbo-16k',
    'purgpt-gpt-3.5-turbo',
    'purgpt-text-davinci-003'
]

if os.environ.get('HIDE_OTHER_PROVIDERS', 'false') == 'true':
    MODELS = ONLINE_MODELS 
else:
    MODELS = ONLINE_MODELS

if os.environ.get('SHOW_ALL_PROVIDERS', 'false') == 'true':
    MODELS = ONLINE_MODELS + NAGA_MODELS + PURGPT_MODELS
else:
    MODELS = ONLINE_MODELS

DEFAULT_MODEL = 0

os.makedirs("history", exist_ok=True)

MODEL_TOKEN_LIMIT = {
    "gpt-3.5-turbo": 4096,
    "gpt-3.5-turbo-16k": 16384,
    "gpt-3.5-turbo-0301": 4096,
    "gpt-3.5-turbo-0613": 4096,
    "gpt-4": 8192,
    "gpt-4-0314": 8192,
    "gpt-4-0613": 8192,
    "gpt-4-32k": 32768,
    "neuro-gpt-4": 8192,
    "neuro-gpt-4-0314": 8192,
    "neuro-gpt-4-0613": 8192,
    "neuro-gpt-4-32k": 32768,
    "neuro-gpt-4-32k-0613": 32768,
    "gpt-4-32k-poe": 32768,
    "gpt-3.5-turbo-16k-openai": 16384,
    "gpt-3.5-turbo-16k-poe": 16384,
    "gpt-4": 8192,
    "gpt-4-0613": 8192,
    "gpt-4-poe": 8192,
    'claude-2': 100000,
    "claude-instant-100k": 100000,
    "claude-2-100k": 100000,
    'naga-gpt-3.5-turbo-16k': 16384,
    'naga-gpt-4': 8192,
    'naga-llama-2-70b-chat': 4096,
    'chatty-gpt-3.5-turbo-16k': 16384,
    'chatty-gpt-4': 8192,
    'purgpt-gpt-3.5-turbo-16k': 16384,
    'purgpt-gpt-3.5-turbo': 4096,
    'purgpt-text-davinci-003': 4096,
    'naga-text-davinci-003': 4096,
    'text-davinci-003': 4096,
    'daku-gpt-4': 8192,
    'daku-gpt-4-32k': 32768,
    'daku-claude-2': 100000,
    'daku-claude-2-100k': 100000,
    'daku-codellama-34b': 4096,
    'daku-llama-2-70b': 4096,
}

TOKEN_OFFSET = 1000 
DEFAULT_TOKEN_LIMIT = 4096 
REDUCE_TOKEN_FACTOR = 0.5

REPLY_LANGUAGES = [
    "Русский",
    "English"
]


WEBSEARCH_PTOMPT_TEMPLATE = """\
Web search results:

{web_results}
Current date: {current_date}

Instructions: Using the provided web search results, write a comprehensive reply to the given query. Make sure to cite results using [[number](URL)] notation after the reference. If the provided search results refer to multiple subjects with the same name, write separate answers for each subject.
Query: {query}
Reply in {reply_language}
"""

PROMPT_TEMPLATE = """\
Context information is below.
---------------------
{context_str}
---------------------
Current date: {current_date}.
Using the provided context information, write a comprehensive reply to the given query.
Make sure to cite results using [number] notation after the reference.
If the provided context information refer to multiple subjects with the same name, write separate answers for each subject.
Use prior knowledge only if the given context didn't provide enough information.
Answer the question: {query_str}
Reply in {reply_language}. Respond using Markdown.
"""

REFINE_TEMPLATE = """\
The original question is as follows: {query_str}
We have provided an existing answer: {existing_answer}
We have the opportunity to refine the existing answer
(only if needed) with some more context below.
------------
{context_msg}
------------
Given the new context, refine the original answer to better
Reply in {reply_language}
If the context isn't useful, return the original answer.
"""

SUMMARIZE_PROMPT = """Write a concise summary of the following:

{text}

CONCISE SUMMARY IN RUSSIAN:"""

ALREADY_CONVERTED_MARK = "<!-- ALREADY CONVERTED BY PARSER. -->"

small_and_beautiful_theme = gr.themes.Soft(
        primary_hue=gr.themes.Color(
            c50="#EBFAF2",
            c100="#CFF3E1",
            c200="#A8EAC8",
            c300="#77DEA9",
            c400="#3FD086",
            c500="#02C160",
            c600="#06AE56",
            c700="#05974E",
            c800="#057F45",
            c900="#04673D",
            c950="#2E5541",
            name="small_and_beautiful",
        ),
        secondary_hue=gr.themes.Color(
            c50="#576b95",
            c100="#576b95",
            c200="#576b95",
            c300="#576b95",
            c400="#576b95",
            c500="#576b95",
            c600="#576b95",
            c700="#576b95",
            c800="#576b95",
            c900="#576b95",
            c950="#576b95",
        ),
        neutral_hue=gr.themes.Color(
            name="gray",
            c50="#f6f7f8",
            # c100="#f3f4f6",
            c100="#F2F2F2",
            c200="#e5e7eb",
            c300="#d1d5db",
            c400="#B2B2B2",
            c500="#808080",
            c600="#636363",
            c700="#515151",
            c800="#393939",
            # c900="#272727",
            c900="#2B2B2B",
            c950="#171717",
        ),
        radius_size=gr.themes.sizes.radius_sm,
    ).set(
        # button_primary_background_fill="*primary_500",
        button_primary_background_fill_dark="*primary_600",
        # button_primary_background_fill_hover="*primary_400",
        # button_primary_border_color="*primary_500",
        button_primary_border_color_dark="*primary_600",
        button_primary_text_color="wihte",
        button_primary_text_color_dark="white",
        button_secondary_background_fill="*neutral_100",
        button_secondary_background_fill_hover="*neutral_50",
        button_secondary_background_fill_dark="*neutral_900",
        button_secondary_text_color="*neutral_800",
        button_secondary_text_color_dark="white",
        # background_fill_primary="#F7F7F7",
        # background_fill_primary_dark="#1F1F1F",
        # block_title_text_color="*primary_500",
        block_title_background_fill_dark="*primary_900",
        block_label_background_fill_dark="*primary_900",
        input_background_fill="#F6F6F6",
        chatbot_code_background_color="*neutral_950",
        chatbot_code_background_color_dark="*neutral_950",
    )
