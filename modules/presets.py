# -*- coding:utf-8 -*-
import os
from pathlib import Path
import gradio as gr
from .webui_locale import I18nAuto

i18n = I18nAuto()  # internationalization

CHATGLM_MODEL = None
CHATGLM_TOKENIZER = None
LLAMA_MODEL = None
LLAMA_INFERENCER = None

# ChatGPT 设置
INITIAL_SYSTEM_PROMPT = "You are a helpful assistant."
API_HOST = "http://127.0.0.1:1337"
COMPLETION_URL = "http://127.0.0.1:1337/v1/chat/completions"
BALANCE_API_URL="https://api.openai.com/dashboard/billing/credit_grants"
USAGE_API_URL="https://api.openai.com/dashboard/billing/usage"
HISTORY_DIR = Path("history")
HISTORY_DIR = "history"
TEMPLATES_DIR = "templates"

# 错误信息
STANDARD_ERROR_MSG = i18n("☹️发生了错误：")  # 错误信息的标准前缀
GENERAL_ERROR_MSG = i18n("获取对话时发生错误，请查看后台日志")
ERROR_RETRIEVE_MSG = i18n("请检查网络连接，或者API-Key是否有效。")
CONNECTION_TIMEOUT_MSG = i18n("连接超时，无法获取对话。")  # 连接超时
READ_TIMEOUT_MSG = i18n("读取超时，无法获取对话。")  # 读取超时
PROXY_ERROR_MSG = i18n("代理错误，无法获取对话。")  # 代理错误
SSL_ERROR_PROMPT = i18n("SSL错误，无法获取对话。")  # SSL 错误
NO_APIKEY_MSG = i18n("API key为空，请检查是否输入正确。")  # API key 长度不足 51 位
NO_INPUT_MSG = i18n("请输入对话内容。")  # 未输入对话内容
BILLING_NOT_APPLICABLE_MSG = i18n("账单信息不适用") # 本地运行的模型返回的账单信息

TIMEOUT_STREAMING = 60  # 流式对话时的超时时间
TIMEOUT_ALL = 200  # 非流式对话时的超时时间
ENABLE_STREAMING_OPTION = True  # 是否启用选择选择是否实时显示回答的勾选框
HIDE_MY_KEY = True  # 如果你想在UI中隐藏你的 API 密钥，将此值设置为 True
CONCURRENT_COUNT = 100 # 允许同时使用的用户数量

SIM_K = 5
INDEX_QUERY_TEMPRATURE = 1.0

CHUANHU_TITLE = i18n("川虎Chat 🚀")

CHUANHU_DESCRIPTION = i18n("由Bilibili [土川虎虎虎](https://space.bilibili.com/29125536)、[明昭MZhao](https://space.bilibili.com/24807452) 和 [Keldos](https://github.com/Keldos-Li) 开发<br />访问川虎Chat的 [GitHub项目](https://github.com/GaiZhenbiao/ChuanhuChatGPT) 下载最新版脚本")


ONLINE_MODELS = [
    "gpt-3.5-turbo",
    "gpt-3.5-turbo-16k",
    #"claude-2",
    'gpt-3.5-turbo-16k-openai (Chimera API)',
    'gpt-4 (Chimera API)',
    'gpt-4-32k-poe (Chimera API)',
    'claude_instant (Chimera API)',
    'claude-instant-100k (Chimera API)',
    'claude-2-100k (Chimera API)',
    'sage (Chimera API)'
]

LOCAL_MODELS = [
    "chatglm-6b",
    "chatglm-6b-int4",
    "chatglm-6b-int4-ge",
    "chatglm2-6b",
    "chatglm2-6b-int4",
    "StableLM",
    "MOSS",
    "llama-7b-hf",
    "llama-13b-hf",
    "llama-30b-hf",
    "llama-65b-hf",
]

if os.environ.get('HIDE_LOCAL_MODELS', 'false') == 'true':
    MODELS = ONLINE_MODELS
else:
    MODELS = ONLINE_MODELS

DEFAULT_MODEL = 0

os.makedirs("models", exist_ok=True)
os.makedirs("lora", exist_ok=True)
os.makedirs("history", exist_ok=True)
for dir_name in os.listdir("models"):
    if os.path.isdir(os.path.join("models", dir_name)):
        if dir_name not in MODELS:
            MODELS.append(dir_name)

MODEL_TOKEN_LIMIT = {
    "gpt-3.5-turbo": 4096,
    "gpt-3.5-turbo-16k": 16384,
    "gpt-3.5-turbo-0301": 4096,
    "gpt-3.5-turbo-0613": 4096,
    "gpt-4": 8192,
    "gpt-4-0314": 8192,
    "gpt-4-0613": 8192,
    "gpt-4-32k": 32768,
    "gpt-4-32k-poe": 32768,
    "gpt-3.5-turbo-16k-openai": 16384,
    "gpt-3.5-turbo-16k-poe": 16384,
    "gpt-4": 8192,
    "gpt-4-0613": 8192,
    "gpt-4-poe": 8192,
    'claude-2': 100000,
    "claude-instant-100k": 100000,
    "claude-2-100k": 100000,
}

TOKEN_OFFSET = 1000 # Вычитайте это значение из лимита токенов модели, чтобы получить мягкий предел. После достижения мягкого предела попробуйте снизить использование токенов. 
DEFAULT_TOKEN_LIMIT = 4096 # Предел токенов по умолчанию 
REDUCE_TOKEN_FACTOR = 0.5 # Умножьте на лимит токенов модели, чтобы получить целевое количество токенов. При снижении использования токенов уменьшите его до значения ниже целевого количества токенов.

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

CONCISE SUMMARY IN РУССКИЙ:"""

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
