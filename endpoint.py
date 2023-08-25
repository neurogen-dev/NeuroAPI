import os
import time
import json
import random
import time

from fastapi import FastAPI, Request
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import json
from typing import List
import os
import random
import time
import asyncio
from starlette.middleware.cors import CORSMiddleware

import logging
import uvicorn

import g4f

from multiprocessing import Process


def setup_logging():
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)

    root_logger.addHandler(handler)

def run_api_server():
    uvicorn.run("backend:app", host="0.0.0.0", port=1337)


if __name__ == "__main__":
    api_process = Process(target=run_api_server) 
    api_process.start()