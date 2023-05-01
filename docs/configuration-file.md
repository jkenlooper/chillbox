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

# The 'remote' list is optional and appends the secret to the append-dest file.
[[secret.remote]]
append-dest = "/home/alice/example-secrets.txt"

# Secret can be shared to other users by including a 'user' attribute. 
[[secret.remote]]
append-dest = "/usr/lib/share/weboftomorrow/secret.cfg"
user = "weboftomorrow"
[[secret.remote]]
append-dest = "/usr/lib/share/site1/secret.cfg"
user = "site1"

# The 'access_key_id' and 'secret_access_key' secrets are common to set up if
# the server needs to access S3 object storage and is not an EC2 instance (an
# EC2 instance would just use the instance profile role for S3 permissions).
# These secrets can be referred to in the 'chillbox:s3-credentials.jinja'
# template and rendered with the 's3-credentials-example' example path below.
[[secret]]
id = "access_key_id"
name = "ACCESS_KEY_ID"
prompt = "Enter the access key id for the S3 object storage being used."
expires = 2023-08-16
owner = "alice"
[[secret]]
id = "secret_access_key"
name = "SECRET_ACCESS_KEY"
prompt = "Enter the secret access key for the S3 object storage being used."
expires = 2023-08-16
owner = "alice"

# Can also load files as secrets by setting the 'type' attribute to 'file'. The
# prompt will be for a file path which will store the content of that file as
# the secret value. The typical use case would be to reference this secret in
# a template. It could also just be uploaded to the server as well.
[[secret]]
id = "example_secret_file"
name = "EXAMPLE_SECRET_FILE_CONTENT"
type = "file"
prompt = "Enter the file path to store the content as a secret."
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

# A path can set the 'sensitive' attribute to 'true' to encrypt that file when
# uploading it. The 'dest' path will then be appended to the PATH_SENSITIVE
# value which is /var/lib/chillbox/path_sensitive/. This example shows a typical
# use case where the s3 credentials are being encrypted after they are rendered
# from that s3-credentials.jinja template. The template references the
# ACCESS_KEY_ID and SECRET_ACCESS_KEY secrets. The encrypted file will be
# written to /var/lib/chillbox/path_sensitive/alice/home/alice/.aws/credentials
# (path joined from PATH_SENSITIVE, OWNER, and DEST).
[[path]]
id = "s3-credentials-example"
src = "chillbox:s3-credentials.jinja"
dest = "/home/alice/.aws/credentials"
sensitive = true
render = true
[path.context]
AWS_PROFILE = "example-profile"

# When the 'src' attribute is a directory; it will upload it as an archive file,
# and extract it to the 'dest' directory.
[[path]]
id = "example-docs"
src = "docs"
dest = "/example/sub/docs"


### Servers ###
# Changing login-users updates the user-data file. The pre-run task for remote
# will only add that user and update ssh key.  A remote task must be used in
# order to remove users on a server.

[[server]]
ip = "122.33.44.55"
name = "example-stream-server"
# For this example, 'bob' would not have access to this server.
login-users = [ "alice" ]
secrets = [ "example_secret", "example_secret_file" ]
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
login-users = [ "alice", "bob" ]
secrets = [ "example_secret" ]
remote-files = [ "chillbox-nginx-conf", "bootstrap-chillbox-server.sh", "s3-credentials-example" ]
```
