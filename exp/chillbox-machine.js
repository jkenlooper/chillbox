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

