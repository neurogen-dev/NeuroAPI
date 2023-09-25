import spacy
import numpy as np
import os
from zhconv import convert
import re
import random

# добавьте специфическую для русского языка модель
import ru_core_news_sm

def detect_lang(text):
    # 定义语言占比字典
    lang_dict = {'zh-cn': 0, 'zh-tw': 0, 'en': 0, 'ru': 0, 'other': 0} # добавьте русский язык
    # 随机抽样最多十个字符
    sample = random.sample(text, min(10, len(text)))
    # 计算每种语言的字符占比
    for char in sample:
        if re.search(r'[\u4e00-\u9fa5]', char):
            lang_dict['zh-cn'] += 1
        elif re.search(r'[\u4e00-\u9fff]', char):
            lang_dict['zh-tw'] += 1
        elif re.search(r'[a-zA-Z]', char):
            lang_dict['en'] += 1
        elif re.search(r'[а-яА-Я]', char): # добавьте соответствующий диапазон для русских букв
            lang_dict['ru'] += 1
        else:
            lang_dict['other'] += 1
    # 返回占比最高的语言
    return max(lang_dict, key=lang_dict.get)

class embedding_processing:

    def __init__(self, model_path='./model'):
        self.en_model = spacy.load('en_core_web_sm')
        self.zh_model = spacy.load('zh_core_web_sm')
        self.ru_model = ru_core_news_sm.load() # добавьте модель для русского языка

    def model(self,text):
        lang = detect_lang(text)
        if lang == "zh-tw":
            ans_cn = self.zh_model(convert(text)).vector.tolist()
        else:
            ans_cn = self.zh_model(text).vector.tolist()
        ans = self.en_model(text).vector.tolist()
        return ans_cn+ans

    def embedding(self, text_list):
        embeddings_list = [self.model(text) for text in text_list]
        response_embedding = self.transform_embedding_to_dict(embeddings_list,text_list)
        return response_embedding

    def transform_embedding_to_dict(self, embedding_list, text_list, model_name="text-embedding-ada-002"):
        prompt_tokens = sum(len(text) for text in text_list)
        total_tokens = sum(len(embedding) for embedding in embedding_list)

        transformed_data = {
            "data": [
                {
                    "embedding": embedding,
                    "index": index,
                    "object": "embedding"
                }
                for index, embedding in enumerate(embedding_list)
            ],
            "model": model_name,
            "object": "list",
            "usage": {
                "prompt_tokens": prompt_tokens,
                "total_tokens": total_tokens
            }
        }
        return transformed_data