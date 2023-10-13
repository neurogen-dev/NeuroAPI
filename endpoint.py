import socket
import nest_asyncio
from backend.backend import app
from waitress import serve

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

    serve(app, host='0.0.0.0', port=site_config['port'],threads=4)