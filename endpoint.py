import fastwsgi
from backend import app
from multiprocessing import Process

def run_api_server():
    fastwsgi.run(wsgi_app=app, host='0.0.0.0', port=1337)


if __name__ == "__main__":
    api_process = Process(target=run_api_server) 
    api_process.start()