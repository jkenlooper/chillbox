import { crypto } from "std/crypto";
import { parse } from "std/flags";
import { info } from "std/log";

import { secureKeysDataDir } from "./data-dir.js";

const usageMessage = `
Decrypt a file using a provided private key file in PEM format.

Usage:
  decrypt_file -h
  decrypt_file <options> -
  decrypt_file <options> <file>

Options:
  -h        Show this help message.

  -d        Secure keys data directory

  -o        Path to output the decrypted file

Args:
  -         Decrypt what is passed to stdin

  <file>    Decrypt the provided file

`;

const { decrypt, importKey } = crypto.subtle;

const parsedArgs = parse(Deno.args);
if (parsedArgs["h"] || parsedArgs["help"]) {
  usage();
} else if (parsedArgs._.length !== 1) {
  usage();
}

const chillboxKeysDataDir = await secureKeysDataDir(parsedArgs["d"]);
const outputFile = parsedArgs["o"];
const encryptedFile = parsedArgs._[0];

const p = Deno.run({ cmd: ["hostname", "-s"], stdout: "piped" });
const processStatus = await p.status();

if (!processStatus.success) {
  throw new Error("Failed to run 'hostname' cmd.");
}
const keyNameRawOutput = await p.output();
const keyName = (new TextDecoder().decode(keyNameRawOutput)).trim();

const privatePemFile = `${chillboxKeysDataDir}/${keyName}.private.pem`;

const privateKey = await importPrivateKey(privatePemFile);
await decryptFile(privateKey, encryptedFile, outputFile);

// Convert from a binary string to an ArrayBuffer
// from https://developers.google.com/web/updates/2012/06/How-to-convert-ArrayBuffer-to-and-from-String
function str2ab(str) {
  const buf = new ArrayBuffer(str.length);
  const bufView = new Uint8Array(buf);
  for (let i = 0, strLen = str.length; i < strLen; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}

async function importPrivateKey(privatePemFile) {
  const decoder = new TextDecoder("utf-8");
  const pemFileData = await Deno.readFile(privatePemFile);
  const pem = decoder.decode(pemFileData);

  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = pem.substring(
    pemHeader.length,
    pem.length - pemFooter.length,
  );
  const binaryDerString = atob(pemContents);
  const binaryDer = str2ab(binaryDerString);

  return importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSA-OAEP",
      hash: "SHA-512",
    },
    false,
    ["decrypt"],
  );
}

async function decryptFile(privateKey, file, outFile) {
  let ciphertext;
  if (file === "-") {
    ciphertext = await Deno.readAll(Deno.stdin);
  } else {
    ciphertext = await Deno.readFile(file);
  }

  const plaintext = await decrypt(
    {
      name: "RSA-OAEP",
    },
    privateKey,
    ciphertext,
  );
  await Deno.writeFile(outFile, plaintext);
}

function usage() {
  info(usageMessage);
  Deno.exit();
}
