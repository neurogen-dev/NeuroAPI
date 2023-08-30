import random
import requests
import time
import threading
import socket
import redis


# Создаем подключение к redis
r = redis.StrictRedis(host='localhost', port=6379, db=0)


def fetch_proxies():
    url = "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http"
    response = requests.get(url)
    if response.status_code == 200:
        return response.text.split("\r\n")[:-1]
    print(f"Error fetching proxies: {response.status_code}")
    return [] 


def test_proxy(proxy, prompt, timeout):
    try:
        ip, port = proxy.split(':') 
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        start_time = time.time()
        sock.connect((ip, int(port)))
        end_time = time.time()
        elapsed_time = end_time - start_time
        sock.close()

        if elapsed_time < timeout:
            print(f"proxy: {proxy} ✅ | Elapsed time: {elapsed_time} seconds")
            r.rpush('working_proxies', proxy)  # Сохраняем рабочего прокси в redis
    except Exception as e:
        pass


def get_working_proxies(prompt, timeout=1):  
    proxy_list = fetch_proxies()  
    threads = []
    r.delete('working_proxies')  # Очищаем список рабочих прокси в redis перед обновлением
  
    for proxy in proxy_list:  
        thread = threading.Thread(target=test_proxy, args=(proxy, prompt, timeout))  
        threads.append(thread)  
        thread.start()  
  
    for t in threads:  
        t.join(timeout)


def update_working_proxies():  
    test_prompt = "What is the capital of France?"  
 
    while True:  
        get_working_proxies(test_prompt)  
        print('proxies updated')  
        time.sleep(1800)  # Обновляем список прокси каждые 30 минут
  
  
def get_random_proxy(): 
    # Получаем случайного прокси из рабочих 
    working_proxies = r.lrange('working_proxies', 0, -1)
    return random.choice(working_proxies)
