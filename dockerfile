FROM python:3.10

WORKDIR /app

COPY . .

RUN pip install --upgrade pip 
RUN pip install -r requirements.txt
RUN pip install --upgrade pip && \
    pip install -r requirements.txt && \
    python -m spacy download ru_core_news_sm  && \
    python -m spacy download en_core_web_sm && \
    python -m spacy download zh_core_web_sm

EXPOSE 7860
EXPOSE 1337

CMD ["python", "webui_ru.py"]
