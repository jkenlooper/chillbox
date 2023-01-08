import { interpret } from 'xstate';

import { chillboxMachine } from './chillbox-machine.js';
import { runCommand } from './run-command.js';

const chillboxMachineDeno = chillboxMachine.withConfig({
    services: {
      "Run command": runCommand
    }
});

const chillboxService = interpret(chillboxMachineDeno).onTransition(async (state) => {
  if (state.changed) {
    console.log("state changed", state.value);

    const decoder = new TextDecoder("utf-8");
    const data = await Deno.readFile("./states.txt");
    console.log(decoder.decode(data));

  }
});

chillboxService.start();
