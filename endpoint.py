import fastwsgi
import socket
from backend import app
from multiprocessing import Process

def run_api_server():
    fastwsgi.run(wsgi_app=app, host='0.0.0.0', port=1337)


if __name__ == "__main__":
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    site_config = {
        'host': '0.0.0.0',
        'port': 1337,
        'debug': False
         }
    print(f"Running on http://127.0.0.1:{site_config['port']}")
    print(f"Running on http://{ip_address}:{site_config['port']}")

    api_process = Process(target=run_api_server) 
    api_process.start()