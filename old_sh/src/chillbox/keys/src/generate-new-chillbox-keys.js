import { crypto } from "std/crypto";
import { info } from "https://deno.land/std@0.158.0/log/mod.ts?s=info";

import { secureKeysDataDir } from "./data-dir.js";

const usageMessage = `


##########################################
WARNING: No longer maintained! Do not use.
##########################################


`;
info(usageMessage);

const { generateKey, exportKey } = crypto.subtle;
const chillboxKeysDataDir = await secureKeysDataDir(Deno.args[0]);
generateNewChillboxKey(chillboxKeysDataDir);

async function generateNewChillboxKey(dataDir) {
  const p = Deno.run({ cmd: ["hostname", "-s"], stdout: "piped" });
  const processStatus = await p.status();

  if (!processStatus.success) {
    throw new Error("Failed to run 'hostname' cmd.");
  }
  const keyNameRawOutput = await p.output();
  const keyName = (new TextDecoder().decode(keyNameRawOutput)).trim();

  const publicPemFile = `${dataDir}/${keyName}.public.pem`;
  const privatePemFile = `${dataDir}/${keyName}.private.pem`;

  const hasExistingPublicPemFile = await checkExistingPemFile(publicPemFile);
  const hasExistingPrivatePemFile = await checkExistingPemFile(privatePemFile);
  if (hasExistingPublicPemFile || hasExistingPrivatePemFile) {
    Deno.exit(4);
  }

  /*
   The RSA-OAEP is asymmetric (public/private key) algorithm that can be used
   for encryption and decryption.
  */
  generateKey(
    {
      name: "RSA-OAEP",
      modulusLength: 4096,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-512",
    },
    true,
    ["encrypt", "decrypt"],
  ).then((keyPair) => {
    exportCryptoKey(privatePemFile, keyPair.privateKey);
    exportCryptoKey(publicPemFile, keyPair.publicKey);
  });
}

async function checkExistingPemFile(pemFile, key) {
  // Expect to not already have a file at the path.
  let existingPemFileInfo;
  try {
    existingPemFileInfo = await Deno.stat(pemFile);
  } catch (err) {
    if (!err instanceof Deno.errors.NotFound) {
      throw err;
    }
  }
  if (existingPemFileInfo) {
    console.log(`Pem file already exists: ${pemFile}`);
    return true;
  }
  return false;
}

/*
Convert an ArrayBuffer into a string
from https://developer.chrome.com/blog/how-to-convert-arraybuffer-to-and-from-string/
*/
function ab2str(buf) {
  return String.fromCharCode.apply(null, new Uint8Array(buf));
}

async function exportCryptoKey(pemFile, key) {
  const exported = await exportKey(
    key.type === "public" ? "spki" : "pkcs8",
    key,
  );
  await Deno.writeTextFile(
    pemFile,
    `-----BEGIN ${key.type.toUpperCase()} KEY-----\n${
      btoa(ab2str(exported))
    }\n-----END ${key.type.toUpperCase()} KEY-----`,
  );

  // Only allow reading it after it is written to prevent chance of overwriting
  // the generated key files.
  await Deno.chmod(pemFile, 0o400);
}
