# Stage 1: Build

FROM python:3.10-slim-buster as builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends build-essential git
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.10-slim-buster

WORKDIR /app

COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY . .
RUN python -m spacy download ru_core_news_sm && \
    python -m spacy download en_core_web_sm && \
    python -m spacy download zh_core_web_sm
RUN chmod +x entrypoint.sh

EXPOSE 7860
EXPOSE 1337

ENV LANG=ru

CMD ["./entrypoint.sh"]
