import socket
import nest_asyncio
from backend.backend import app
from gevent import pywsgi
from multiprocessing import Process

nest_asyncio.apply()

site_config = {
        'host': '0.0.0.0',
        'port': 1337,
        'debug': False
         }

if __name__ == "__main__":
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)

    print(f"Running on http://127.0.0.1:{site_config['port']}")
    print(f"Running on http://{ip_address}:{site_config['port']}")

    server = pywsgi.WSGIServer(('0.0.0.0', site_config['port']), app)
    server.serve_forever()