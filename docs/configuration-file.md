# Chillbox Configuration File

In TOML format to allow comments.

Required top level keys:

- "instance"
- "gpg-key"
- "archive-directory"

Optional:

- "env"
- list of "user"
- list of "secret"
- list of "local-file"
- list of "remote-file"
- list of "server"


## Example

```toml
instance = "example"
gpg-key = "example"
archive-directory = ".chillbox"

### User ###
# Removing a user here does not automatically remove them from the servers.
# A remote task would need to do that.

# Use the public GitHub API if the user has an account on GitHub. Copy and paste
# the response from chillbox sub-command (replace USERNAME):
# chillbox fetch-github-public-ssh-key --user=USERNAME

[[user]]
name = "alice"
public-ssh-key = [
  "public-ssh-key-that-is-manually-added-here"
]

[[user]]
name = "bob"
public-ssh-key = [
  "public-ssh-key-that-is-manually-added-here"
]

### Environment ###

[env]
ENVIRONMENT = "development"


### Secrets ###
# The secret is encrypted to each server's public key before being uploaded to
# append-dest. The append-dest file will have two other sibling files:
# - .sha512 For storing a hash of the secrets before encryption.
# - .aes For storing the encrypted data key (first 512 bytes) and the encrypted
#   file.
# The append-dest file is only unencrypted at the location with the server's
# private key.
# It is recommended to mount a tmpfs file system at the directory that secrets
# are placed in to be more secure.

[[secret]]
id = "example_secret"
name = "SECRET_KEY"
prompt = "Enter secret key"
expires = 2023-03-16
owner = "alice"
# Secret can be shared by two users
[[secret.remote]]
append-dest = "/usr/lib/share/weboftomorrow/secret.cfg"
user = "weboftomorrow"
[[secret.remote]]
append-dest = "/usr/lib/share/site1/secret.cfg"
user = "site1"

### Files ###

# Copies these files from the host machine to the archive.
[[local-file]]
name = "example-built-tar-file"
src = "path/to/example-built-tar-file/on-host"
dest = "path/to/example-built-tar-file/to-store-in-archive"

[[local-file]]
name = "terraform-output-example"
src = "path-to/file-that-might/not-exist-yet.json"
optional = true
dest = "example/terraform-stuff/output.json"

[[remote-file]]
name = "stream-nginx-conf"
template = "/path/to/template.nginx.conf.jinja2"
dest = "/etc/nginx/conf.d/example-stream.nginx.conf"
[remote-file.context]
domains = ["abc.example.com"]

[[remote-file]]
name = "bootstrap-stream-nginx-server.sh"
src = "/path/to/bootstrap-stream-nginx-server.sh"
dest = "/path/to/bootstrap-stream-nginx-server.sh"

[[remote-file]]
name = "chillbox-nginx-conf"
template = "/path/to/template.nginx.conf.jinja2"
dest = "/etc/nginx/conf.d/chillbox.nginx.conf"
[remote-file.context]
domains = ["abc.chillbox.example.com"]

[[remote-file]]
name = "bootstrap-chillbox-server.sh"
src = "/path/to/bootstrap-chillbox-server.sh"
dest = "/path/to/bootstrap-chillbox-server.sh"


### Servers ###
# Changing login-users and no-home-users updates the user-data file. The pre-run
# task for remote will only add that user and update ssh key.  A remote task
# must be used in order to remove users on a server.

[[server]]
ip = "122.33.44.55"
name = "example-stream-server"
# For this example, 'bob' would not have access to this server.
login-users = [ "alice:dev" ]
no-home-users = [ "dev" ]
secrets = [ "example_secret" ]
[server.user-data]
template = "chillbox/user-data.sh.jinja"
# A user-data script may have limits to the file size depending on the cloud
# host.
# AWS EC2 limit is 16K
# DigitalOcean limit is 64K
# Vultr limit is unknown
# Set an optional limit on the generated file size to this many bytes (16K).
file-size-limit = 16384
[server.user-data.context]
something = "example"
user = "alice"
user_pw_hash = ""
public-ssh-key = [
  "public-ssh-key-that-is-manually-added-here"
]
nft_script = "example.nft"


remote-files = [ "stream-nginx-conf", "bootstrap-stream-nginx-server.sh" ]

[[server]]
ip = "122.3.4.5"
name = "example-web-server-for-bob"
login-users = [ "alice:dev", "bob:dev" ]
no-home-users = [ "dev", "weboftomorrow", "site1" ]
secrets = [ "example_secret" ]
remote-files = [ "chillbox-nginx-conf", "bootstrap-chillbox-server.sh" ]
```
