import invoke


class ChillboxExit(invoke.exceptions.Exit):
    "Base class for chillbox errors that require exiting."


class ChillboxMissingFileError(ChillboxExit):
    "Missing required file"


class ChillboxInvalidConfigError(ChillboxExit):
    "Invalid configuration"


class ChillboxDependencyError(ChillboxExit):
    """"""


class ChillboxGPGError(ChillboxExit):
    """"""


class ChillboxArchiveDirectoryError(ChillboxExit):
    "Archive directory error"

class ChillboxHTTPError(ChillboxExit):
    """"""

class ChillboxServerUserDataError(ChillboxExit):
    """"""

class ChillboxExpiredSecretError(ChillboxExit):
    """"""

class ChillboxInvalidStateFileError(ChillboxExit):
    """"""
