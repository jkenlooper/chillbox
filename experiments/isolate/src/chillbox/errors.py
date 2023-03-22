import invoke

class ChillboxExit(invoke.exceptions.Exit):
    "Base class for chillbox errors that require exiting."


class ChillboxInvalidConfigError(ChillboxExit):
    "Invalid configuration"

class ChillboxDependencyError(ChillboxExit):
    ""

