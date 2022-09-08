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
      initial: "idle",
      states: {
        idle: {},
      },
      invoke: {
        src: {
          type: "execute_cmd",
          cmd: "./show-environment.sh",
          args: ["-a", "one"]
        },
        id: "invoke-show-environment",
        onDone: {
          target: "check_args_and_environment_vars",
          actions: assign({ exitcode: (context, event) => event.exitcode }),
          cond: "exit0"
        },
        onError: {
          target: "failed"
        }
      }
    },
    check_args_and_environment_vars: {
    },
    failed: {}
  },
},
  {
    actions: {
    },
    guards: {
      exit0: (context, event) => {
        console.log("Guard exit0");
        return event.data.exitcode === 0;
      }
    },
    services: {
      execute_cmd: (context, event, { src }) => new Promise((resolve, reject) => {
        console.log("execute cmd ", src);
        return resolve({exitcode: 0});
      })
    }
  }
);

const testService = interpret(chillboxMachine).onTransition((state) => {
  if (state.changed) {
    console.log("state changed", state.value);
  }
});

testService.start();
