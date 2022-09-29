import { crypto } from "std/crypto";
import { parse } from "std/flags";

const { encrypt, importKey } = crypto.subtle;

const parsedArgs = parse(Deno.args);
if (parsedArgs["h"] || parsedArgs["help"]) {
  usage();
} else if (parsedArgs._.length !== 1) {
  usage();
}

const publicPemFile = parsedArgs["public-key-pem-file"];
const outputFile = parsedArgs["output-file"];
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
  const pemContents = pem.substring(pemHeader.length, pem.length - pemFooter.length);
  console.log(pemContents);
  const binaryDerString = atob(pemContents);
  const binaryDer = str2ab(binaryDerString);

  return importKey(
    "spki",
    binaryDer,
    {
      name: "RSA-OAEP",
      hash: "SHA-512"
    },
    true,
    ["encrypt"]
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
  console.log("bytes", plaintext.byteLength);
  if (plaintext.byteLength > 382) {
    console.log("plaintext byte length is over the 382 byte limit allowed for the key.");
    Deno.exit(4);
  }
  // TODO Should include a symmetric key as payload instead to avoid the limit?

  const ciphertext = await encrypt({
    name: "RSA-OAEP"
  },
    publicKey,
    plaintext
  );
  await Deno.writeFile(outFile, ciphertext);
}

function usage() {
  console.log("hi");
  //const parsedArgs = parse(["--public-key-pem-file=publicKeyFile", "--output-file=outputFile", "./quux.txt"]);
  Deno.exit();
}
