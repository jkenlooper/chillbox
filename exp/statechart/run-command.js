
const runCommand = (context, event, { src }) => new Promise(async (resolve, reject) => {
  console.log("run cmd ", src);

  let p;
  try {
    p = Deno.run({
      cmd: [
        src.cmd,
        ...src.args
      ],
      stdout: "piped",
      stderr: "piped"
    });
  } catch (err) {
    if (err instanceof Deno.errors.NotFound) {
      return reject(err);
    } else {
      throw err;
    }
  }
  const processStatus = await p.status();
  console.log("processStatus", processStatus);

  // Reading the outputs closes their pipes
  const rawOutput = await p.output();
  const rawError = await p.stderrOutput();

  if (processStatus.success) {
    await Deno.stdout.write(rawOutput);
  } else {
    const errorString = new TextDecoder().decode(rawError);
    console.log("error", errorString);
  }

  return resolve({exitcode: processStatus.code});
});

export { runCommand };
