from pathlib import Path
import json

from chillbox.errors import ChillboxInvalidStateFileError


class ChillboxState:
    """"""

    statefile_json = "statefile.json"

    def __init__(self, archive_directory):
        self.archive_directory = Path(archive_directory)

        self._state_file = self.archive_directory.joinpath(self.statefile_json)

        self._load_state_file_data()

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
            data = {}

        self._output_env_temp = data.get("output_env_temp", "")
        self._current_user = data.get("current_user", "")
        self._current_user_data = data.get("current_user_data", {})
        self._ssh_config_temp = data.get("ssh_config_temp", "")
        self._identity_file_temp = data.get("identity_file_temp", "")
        self._local_chillbox_asymmetric_key_private = data.get(
            "local_chillbox_asymmetric_key_private", ""
        )

    def _save_state_file_data(self):
        data = {
            "output_env_temp": self.output_env_temp,
            "current_user": self.current_user,
            "current_user_data": self.current_user_data,
            "ssh_config_temp": self.ssh_config_temp,
            "identity_file_temp": self.identity_file_temp,
            "local_chillbox_asymmetric_key_private": self.local_chillbox_asymmetric_key_private,
        }
        with open(self._state_file, "w") as f:
            json.dump(data, f, indent=2, sort_keys=True)

    @property
    def output_env_temp(self):
        return self._output_env_temp

    @output_env_temp.setter
    def output_env_temp(self, value):
        self._output_env_temp = value
        self._save_state_file_data()

    @property
    def current_user(self):
        return self._current_user

    @current_user.setter
    def current_user(self, value):
        if not value:
            raise Exception("invalid value for current_user")
        self._current_user = value
        self._save_state_file_data()

    @property
    def current_user_data(self):
        return self._current_user_data

    @current_user_data.setter
    def current_user_data(self, value):
        self._current_user_data = value
        self._save_state_file_data()

    @property
    def ssh_config_temp(self):
        return self._ssh_config_temp

    @ssh_config_temp.setter
    def ssh_config_temp(self, value):
        self._ssh_config_temp = value
        self._save_state_file_data()

    @property
    def identity_file_temp(self):
        return self._identity_file_temp

    @identity_file_temp.setter
    def identity_file_temp(self, value):
        self._identity_file_temp = value
        self._save_state_file_data()

    @property
    def local_chillbox_asymmetric_key_private(self):
        return self._local_chillbox_asymmetric_key_private

    @local_chillbox_asymmetric_key_private.setter
    def local_chillbox_asymmetric_key_private(self, value):
        self._local_chillbox_asymmetric_key_private = value
        self._save_state_file_data()
