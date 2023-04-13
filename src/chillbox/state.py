from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
import json
from collections import UserDict

from chillbox.errors import ChillboxInvalidStateFileError


class ChillboxState(UserDict):
    ""
    statefile_json = "statefile.json"
    default_data = {
        "output_env_temp": "",
        "current_user": "",
        "ssh_config_temp": "",
        "identity_file_temp": "",
        "base_images": {},
        "server_images": {},
    }

    def __init__(self, archive_directory):
        self.archive_directory = archive_directory

        self._state_file = self.archive_directory.joinpath(self.statefile_json)

        initialdata = self._load_state_file_data()
        super().__init__(initialdata)
        self._save_state_file_data()


    def _load_state_file_data(self):
        if self._state_file.exists():
            with open(self._state_file, "r") as f:
                try:
                    data = json.load(f)
                except json.decoder.JSONDecodeError as err:
                    raise ChillboxInvalidStateFileError(
                        f"ERROR: Failed to parse json file ({f.name}).\n  {err}"
                    )
        else:
            data = deepcopy(self.default_data)
        return data

    def _save_state_file_data(self):
        with open(self._state_file, "w") as f:
            json.dump(self.data, f, indent=2)

    def __getitem__(self, key):
        self.data = self._load_state_file_data()
        return super().__getitem__(key)

    def __setitem__(self, key, value):
        self.data[key] = value
        self._save_state_file_data()

    def __delitem__(self, key):
        self.data.pop(key)
        self._save_state_file_data()
