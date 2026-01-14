"""Simple demo background worker."""
import os
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    logger.info("Worker starting...")
    while True:
        logger.info(f"Worker processing... (version: {os.getenv('VERSION', '1.0.0')})")
        time.sleep(30)

if __name__ == "__main__":
    main()
