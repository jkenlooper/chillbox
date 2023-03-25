import os
import logging

LOG_FORMAT = "%(levelname)s: %(name)s.%(module)s.%(funcName)s: %(message)s"
logging.basicConfig(level=logging.WARNING, format=LOG_FORMAT)
# Allow invoke debugging mode if the env var is set for it.
logger = logging.getLogger(
    "chillbox" if not os.environ.get("INVOKE_DEBUG") else "invoke"
)
