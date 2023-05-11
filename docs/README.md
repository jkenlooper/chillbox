# Chillbox CLI Documentation

The `chillbox` command is a tool to render local files from templates and
automate uploading files to servers in a secure and automated fashion. It also
requires `gpg` to encrypt a local asymmetric private key that it will generate.
The private key is used to encrypt all rendered local files as well as any
secrets that are stored for the user. A chillbox archive directory will hold
state files needed for a given project. A chillbox configuration file in TOML
format is also required to be made which defines various files, secrets, users,
and server information.

**Documentation for how to use `chillbox`:**

- [Tutorials](#tutorials)
- [How-to guides](#how-to-guides)
- [Technical reference](#technical-reference)
- [Explanation](#explanation)

The `chillbox` script can be installed on the local machine with the Python
package installer `pip`. 

```bash
pip install chillbox
```

## Requirements

Please ensure that these are available on the local machine.

- [Python] version 3.9+
- `gpg`, from [GnuPG]. To encrypt and decrypt the chillbox asymmetric keys that are generated.
- `openssl`, from [OpenSSL]. To create asymmetric and symmetric keys used for encrypting and decrypting sensitive data like secrets.
- Various software that is common on most systems (part of the `coreutils`):
    `mktemp`, `shred`, `dd`.

## Tutorials

1. [Start a _minimal_ project](./tutorials/start-minimal-project.md)


## How-to guides

## Technical reference

## Explanation

---

## Notes

Documentation follows the guidelines set by the [Divio Documentation System].

[Divio Documentation System]: https://documentation.divio.com/
[Python]: https://www.python.org/
[GnuPG]: https://www.gnupg.org/
[OpenSSL]: https://www.openssl.org/
