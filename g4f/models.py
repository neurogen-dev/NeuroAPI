from dataclasses import dataclass
import random

from .Provider import *


@dataclass
class Model:
    name: str
    base_provider: str
    best_provider: type[BaseProvider]

# Config for HuggingChat, OpenAssistant
# Works for Liaobots, H2o, OpenaiChat, Yqcloud, You
default = Model(
    name="",
    base_provider="huggingface",
    best_provider=H2o,
)

# GPT-3.5 / GPT-4
gpt_35_turbo = Model(
    name="gpt-3.5-turbo",
    base_provider="openai",
    best_provider=Wewordle,
)


gpt_4 = Model(
    name="gpt-4",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_4_0314 = Model(
    name="gpt-4-0314",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_4_0613 = Model(
    name="gpt-4-0613",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_4_32k = Model(
    name="gpt-4-32k",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_4_32k_0314 = Model(
    name="gpt-4-32k-0314",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_4_32k_0613 = Model(
    name="gpt-4-32k-0613",
    base_provider="openai",
    best_provider=Vercel,
)

# Bard
palm = Model(
    name="palm",
    base_provider="google",
    best_provider=Bard,
)



# Vercel
claude_instant_v1 = Model(
    name="anthropic:claude-instant-v1",
    base_provider="anthropic",
    best_provider=Vercel,
)

claude_v1 = Model(
    name="anthropic:claude-v1",
    base_provider="anthropic",
    best_provider=Vercel,
)

claude_v2 = Model(
    name="anthropic:claude-v2",
    base_provider="anthropic",
    best_provider=Vercel,
)

command_light_nightly = Model(
    name="cohere:command-light-nightly",
    base_provider="cohere",
    best_provider=Vercel,
)

command_nightly = Model(
    name="cohere:command-nightly",
    base_provider="cohere",
    best_provider=Vercel,
)


santacoder = Model(
    name="huggingface:bigcode/santacoder",
    base_provider="huggingface",
    best_provider=Vercel,
)


code_davinci_002 = Model(
    name="openai:code-davinci-002",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_35_turbo_16k = Model(
    name="openai:gpt-3.5-turbo-16k",
    base_provider="openai",
    best_provider=Vercel,
)

gpt_35_turbo_16k_0613 = Model(
    name="openai:gpt-3.5-turbo-16k-0613",
    base_provider="openai",
    best_provider=Vercel,
)

# gpt_4_0613 = Model(
    # name="openai:gpt-4-0613",
    # base_provider="openai",
    # best_provider=Vercel,
#)

text_ada_001 = Model(
    name="openai:text-ada-001",
    base_provider="openai",
    best_provider=Vercel,
)

text_curie_001 = Model(
    name="openai:text-curie-001",
    base_provider="openai",
    best_provider=Vercel,
)


text_davinci_003 = Model(
    name="openai:text-davinci-003",
    base_provider="openai",
    best_provider=Vercel,
)

llama70b_v2_chat = Model(
    name="replicate:a16z-infra/llama70b-v2-chat",
    base_provider="replicate",
    best_provider=Vercel,
)



class ModelUtils:
    convert: dict[str, Model] = {
        # GPT-3.5 / GPT-4
        "gpt-3.5-turbo": gpt_35_turbo,
        "gpt-3.5-turbo-16k": gpt_35_turbo_16k,
        "gpt-3.5-turbo-16k_0613": gpt_35_turbo_16k_0613,
        "gpt-4": gpt_4,
        "gpt-4-0314": gpt_4_0314,
        "gpt-4-0613": gpt_4_0613,
        "gpt-4-32k": gpt_4_32k,
        "gpt-4-32k-0314": gpt_4_32k_0314,
        "gpt-4-32k-0613": gpt_4_32k_0613,
        # Bard
        "palm2": palm,
        "palm": palm,
        "google": palm,
        "google-bard": palm,
        "google-palm": palm,
        "bard": palm,
        # Vercel
        "claude-instant-v1": claude_instant_v1,
        "claude-v1": claude_v1,
        "claude-v2": claude_v2,
        "command-light-nightly": command_light_nightly,
        "command-nightly": command_nightly,
        "santacoder": santacoder,
        "code-davinci-002": code_davinci_002,
        "gpt-3.5-turbo-16k": gpt_35_turbo_16k,
        "gpt-3.5-turbo-16k-0613": gpt_35_turbo_16k_0613,
        "gpt-4-0613": gpt_4_0613,
        "text-ada-001": text_ada_001,
        "text-curie-001": text_curie_001,
        "text-davinci-003": text_davinci_003,
        "llama70b-v2-chat": llama70b_v2_chat,
    }
