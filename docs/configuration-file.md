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
- list of "template"
- list of "path"
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
# Not setting a public_ssh_key will trigger auto creation of one along with
# a private key that is encrypted.

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
expires = 2024-03-16
owner = "alice"
# Secret can be shared by two users
[[secret.remote]]
append-dest = "/usr/lib/share/weboftomorrow/secret.cfg"
user = "weboftomorrow"
[[secret.remote]]
append-dest = "/usr/lib/share/site1/secret.cfg"
user = "site1"

# Can also load files as secrets
[[secret]]
id = "certbot_account"
name = "CERTBOT_ACCOUNT"
type = "file"
prompt = "Enter the file path for the certbot account that was registered."
owner = "alice"


### Files ###

[[template]]
# Create the example-templates directory first.
src = "example-templates"
# The prefix is optional. Use the 'local' one here like this when rendering a path: 'local:'
prefix = "local"

[[path]]
id = "stream-nginx-conf"
src = "chillbox:stream.nginx.conf.jinja"
dest = "/etc/nginx/conf.d/example-stream.nginx.conf"
render = true
[path.context]
domains = ["abc.example.com"]

# Copies these files from the host machine to the archive.
[[path]]
id = "example-readme"
src = "README.md"
dest = "/example/sub/README.md"

[[path]]
id = "example-docs"
src = "docs"
dest = "/example/sub/docs.tar.gz"


### Servers ###
# Changing login-users and no-home-users updates the user-data file. The pre-run
# task for remote will only add that user and update ssh key.  A remote task
# must be used in order to remove users on a server.

[[server]]
ip = "122.33.44.55"
name = "example-stream-server"
# For this example, 'bob' would not have access to this server.
login-users = [ "alice:dev" ]
secrets = [ "example_secret" ]
remote-files = [ "stream-nginx-conf", "bootstrap-stream-nginx-server.sh" ]
[server.user-data]
template = "chillbox:user-data.sh.jinja"
# A user-data script may have limits to the file size depending on the cloud
# host.
# AWS EC2 limit is 16K
# DigitalOcean limit is 64K
# Vultr limit is unknown
# Set an optional limit on the generated file size to this many bytes (16K).
file-size-limit = 16384
[server.user-data.context]
something = "example"
nft_script = "example.nft"

[[server]]
ip = "122.3.4.5"
name = "example-web-server-for-bob"
login-users = [ "alice:dev", "bob:dev" ]
secrets = [ "example_secret" ]
remote-files = [ "chillbox-nginx-conf", "bootstrap-chillbox-server.sh" ]
```
