import { crypto } from "https://deno.land/std@0.157.0/crypto/mod.ts?s=crypto";
import { parse } from "https://deno.land/std@0.158.0/flags/mod.ts?s=parse";
import { info } from "https://deno.land/std@0.158.0/log/mod.ts?s=info";

const usageMessage = `
Encrypt a small (less than 382 bytes) file using a provided public key file in PEM format.

Usage:
  encrypt_file -h
  encrypt_file <options> -
  encrypt_file <options> <file>

Options:
  -h        Show this help message.

  -k        A public key file in PEM format

  -o        Path to output the encrypted file

Args:
  -         Encrypt what is passed to stdin

  <file>    Encrypt the provided file

`;

const { encrypt, importKey } = crypto.subtle;

const parsedArgs = parse(Deno.args);
if (parsedArgs["h"] || parsedArgs["help"]) {
  usage();
} else if (parsedArgs._.length !== 1) {
  usage();
}

const publicPemFile = parsedArgs["k"];
const outputFile = parsedArgs["o"];
const unencryptedFile = parsedArgs._[0];

const publicKey = await importPublicKey(publicPemFile);
await encryptFile(publicKey, unencryptedFile, outputFile);

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

async function importPublicKey(publicPemFile) {
  const decoder = new TextDecoder("utf-8");
  const pemFileData = await Deno.readFile(publicPemFile);
  const pem = decoder.decode(pemFileData);

  const pemHeader = "-----BEGIN PUBLIC KEY-----";
  const pemFooter = "-----END PUBLIC KEY-----";
  const pemContents = pem.substring(
    pemHeader.length,
    pem.length - pemFooter.length,
  );
  const binaryDerString = atob(pemContents);
  const binaryDer = str2ab(binaryDerString);

  return importKey(
    "spki",
    binaryDer,
    {
      name: "RSA-OAEP",
      hash: "SHA-512",
    },
    true,
    ["encrypt"],
  );
}

async function encryptFile(publicKey, file, outFile) {
  let plaintext;
  if (file === "-") {
    plaintext = await Deno.readAll(Deno.stdin);
  } else {
    plaintext = await Deno.readFile(file);
  }
  // Need to check the length of plaintext since this key is only meant for
  // small payloads.
  // https://crypto.stackexchange.com/questions/42097/what-is-the-maximum-size-of-the-plaintext-message-for-rsa-oaep/42100#42100
  if (plaintext.byteLength > 382) {
    console.log(
      "plaintext byte length is over the 382 byte limit allowed for the key.",
    );
    Deno.exit(4);
  }
  // TODO Should include a symmetric key as payload instead to avoid the limit?
  // See about wrapping the key used to encrypt the payload.

  const ciphertext = await encrypt(
    {
      name: "RSA-OAEP",
    },
    publicKey,
    plaintext,
  );
  await Deno.writeFile(outFile, ciphertext);
}

function usage() {
  info(usageMessage);
  Deno.exit();
}
