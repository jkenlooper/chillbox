async function secureKeysDataDir(dataDir) {
  await Deno.mkdir(dataDir, { recursive: true });
  await Deno.chmod(dataDir, 0o700);
  return dataDir;
}

export { secureKeysDataDir };
