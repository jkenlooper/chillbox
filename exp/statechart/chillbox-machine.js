import { createMachine, interpret, assign } from 'xstate';

const chillboxMachine = createMachine({
  predictableActionArguments: true,
  id: "chillbox",
  initial: "show_environment",
  context: {
    exitcode: undefined,
  },
  states: {
    show_environment: {
      exit: [
        "setExitcode"
      ],
      invoke: {
        src: {
          type: "Run command",
          cmd: "test",
          args: ["-f", "states.txt"]
        },
        id: "invoke-show-environment",
        onDone: {
          target: "check_args_and_environment_vars",
          cond: "exit0"
        },
        onError: {
          target: "failed",
        }
      },
      on: {
        SIGINT: { target: "stopped" }
      }
    },
    check_args_and_environment_vars: {
    },
    failed: {},
    stopped: {
      type: "final"
    }
  },
},
  {
    actions: {
      setExitcode: (context, event) => { assign({ exitcode: (context, event) => event.exitcode })},
    },
    guards: {
      exit0: (context, event) => {
        console.log("Guard exit0");
        return event.data?.exitcode === 0;
      }
    },
    services: {
      "Run command": (context, event, { src }) => new Promise((resolve, reject) => {
        // Testing
        console.log("execute cmd ", src);
        setTimeout(() => {
          return resolve({exitcode: 0});
        }, 5000);
      })
    }
  }
);

export { chillboxMachine };


// https://stately.ai/registry/editor/share/1b1a3595-5a82-4bfe-ba32-ba3b856e59f2
const exportedStateChart =
{
  "id": "on local box",
  "initial": "Running chillbox script",
  "description": "Executing the doit.sh experimental script.",
  "states": {
    "Running chillbox script": {
      "initial": "Get Opts",
      "states": {
        "Get Opts": {
          "on": {
            "done": {
              "target": "show environment"
            }
          }
        },
        "show environment": {
          "on": {
            "done": {
              "target": "check args and environment vars"
            }
          }
        },
        "check args and environment vars": {
          "on": {
            "done": {
              "target": "check for required commands"
            }
          }
        },
        "check for required commands": {
          "on": {
            "done": {
              "target": "init and source chillbox config"
            }
          }
        },
        "init and source chillbox config": {
          "on": {
            "done": {
              "target": "create example site tar gz"
            }
          }
        },
        "create example site tar gz": {
          "on": {
            "done": {
              "target": "validate environment vars"
            }
          }
        },
        "validate environment vars": {
          "on": {
            "done": {
              "target": "build artifacts"
            }
          }
        },
        "build artifacts": {
          "on": {
            "done": {
              "target": "verify built artifacts"
            }
          }
        },
        "verify built artifacts": {
          "on": {
            "done": {
              "target": "generate site domains"
            }
          }
        },
        "generate site domains": {
          "on": {
            "done": {
              "target": "check sub command"
            }
          }
        },
        "check sub command": {
          "on": {
            "Event 2": [
              {
                "cond": "interactive",
                "target": "update ssh keys auto tfvars"
              },
              {
                "cond": "plan",
                "target": "update ssh keys auto tfvars"
              },
              {
                "cond": "apply",
                "target": "update ssh keys auto tfvars"
              },
              {
                "cond": "destroy",
                "target": "update ssh keys auto tfvars"
              },
              {
                "cond": "clean",
                "target": "execute clean script"
              },
              {
                "cond": "pull",
                "target": "execute pull terraform script"
              },
              {
                "cond": "push",
                "target": "execute push terraform script"
              },
              {
                "cond": "secrets",
                "target": "execute secrets script"
              }
            ]
          }
        },
        "update ssh keys auto tfvars": {
          "on": {
            "done": {
              "target": "execute terra script"
            }
          }
        },
        "execute terra script": {},
        "execute clean script": {},
        "execute pull terraform script": {},
        "execute push terraform script": {},
        "execute secrets script": {}
      }
    },
    "Abort": {
      "type": "final",
      "description": "Did not finish the process."
    },
    "Exited script": {
      "type": "final"
    }
  },
  "on": {
    "SIGHUP": {
      "target": ".Abort"
    },
    "SIGINT": {
      "target": ".Abort"
    },
    "SIGQUIT": {
      "target": ".Abort"
    }
  }
}
