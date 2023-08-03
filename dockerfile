FROM python:3.10

WORKDIR /app

COPY . .

RUN pip install --upgrade pip 
RUN pip install -r requirements.txt

EXPOSE 7860
EXPOSE 1337

CMD ["python", "webui.py"]
