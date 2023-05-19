# Chillbox Configuration File

In TOML format to allow comments.

Required top level keys:

- "instance"
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
# The instance is used to identify this chillbox.
instance = "example"

# The directory to use to store the state files among other things.  This
# directory should not be included in source control. It is only useful to the
# current user.
archive-directory = ".chillbox"

### User ###
# Define the users that will have access to the servers listed. The 'name' and
# 'gpg-key' are both required. If the GPG key doesn't exist on the system for
# the current user; then it will prompt to create a new one.
#
# Adding or removing a user here does not automatically add or remove them from
# the servers. However, it is common to add a user to a server via the user-data
# script and reference user details specified in this configuration file.
#
# Use the public GitHub API if the user has an account on GitHub. Copy and paste
# the response from chillbox sub-command (replace USERNAME):
# chillbox fetch-github-public-ssh-key --user=USERNAME

[[user]]
name = "alice"
gpg-key = "alice@example"

public_ssh_key = [
  "public-ssh-key-that-is-manually-added-here"
]
# The password_hash is optional. A prompt to set one will only happen if the
# current user doesn't have one defined.
password_hash = "$6$P5HfG8ffOtULVU4Z$A5kCOky7sjaDVhrvNyXd4aFoAQgdOdNxN.PTsWMhszHQ7JMj29tgYIPnMrg7OdqPhZgzFUdTUpSRrSjJk0vR8."

[[user]]
name = "bob"
gpg-key = "bob@example"
# Not setting a public_ssh_key will trigger auto creation of one along with
# a private key that is encrypted.

### Environment (env) ###

[env]
# Any variables defined here can also be used in jinja templates.
# For example, use them with jinja: {{ ENVIRONMENT }}
ENVIRONMENT = "development"

# Variables can be overridden by setting a 'context' when rendering (path and
# server.user-data does this).  The default for this example is set here. See
# the example path with id 's3-credentials-example' to see how the AWS_PROFILE
# value is overridden.
AWS_PROFILE = "default-example-s3-profile"

# Default env settings; uncomment to change. All defaults will be prefixed with
# 'CHILLBOX_'
#
# The paths defined here are used when encrypted secrets, and files that need to
# remain encrypted, are uploaded to the server. It is not recommended to change
# these.
# CHILLBOX_PATH_SENSITIVE = "/var/lib/chillbox/path_sensitive"
# CHILLBOX_PATH_SECRETS = "/var/lib/chillbox/secrets"
# CHILLBOX_PATH_SECRETS_AND_SENSITIVE_LAST_UPDATE = "/var/lib/chillbox/.watch-chillbox-secrets-and-sensitive-paths/last-update"


### Secrets ###
# The secret is encrypted to each server's public key before being uploaded. The
# secrets are encrypted to the local private key and stored in the local
# chillbox archive directory.  The append-dest file is only unencrypted at the
# location with the server's private key.
#
# It is recommended to mount a tmpfs file system at the directory that the
# unencrypted secrets are placed in to be more secure.
#
# The 'name' attribute is used to assign the secret value. Secrets can be used
# in rendered template files. It is recommended to set the 'sensitive' attribute
# to true in the 'path' item if it uses a secret value.
#
# Note that secret values are not available for user-data scripts that get
# rendered. This is because the user-data is not encrypted and should not
# contain any sensitive values.

[[secret]]
# The 'id' attribute is required and needs to be unique.
id = "example_secret"

# The 'name' attribute should be unique and is used as the key.
name = "SECRET_KEY"

# Secrets will be encrypted when stored. The prompt is a way to enter the secret
# securely when the current user matches the owner.
prompt = "Enter secret key"

# An 'expires' attribute is optional.
expires = 2024-03-16

# All secrets should have an owner that can set them and replace them if needed.
owner = "alice"

# The 'remote' list is optional and appends the secret to the append-dest file.
# The actual path is set with these replaced:
# CHILLBOX_PATH_SECRETS/USER/APPEND_DEST
[[secret.remote]]
append-dest = "/home/alice/example-secrets.txt"

# Secret can be shared to other users by including a 'user' attribute. 
[[secret.remote]]
append-dest = "/usr/lib/share/example1/secret.cfg"
user = "example1"
[[secret.remote]]
append-dest = "/usr/lib/share/site1/secret.cfg"
user = "site1"

# The 'ACCESS_KEY_ID' and 'SECRET_ACCESS_KEY' secrets are common to set up if
# the server needs to access S3 object storage and is not an EC2 instance (an
# EC2 instance would just use the instance profile role for S3 permissions).
# These secrets can be referred to in the 'chillbox:s3-credentials.jinja'
# template and rendered with the 's3-credentials-example' example path below.
[[secret]]
id = "access_key_id__alice"
name = "ACCESS_KEY_ID"
prompt = "Enter the access key id for the S3 object storage being used."
expires = 2023-08-16
owner = "alice"
[[secret]]
id = "secret_access_key__alice"
name = "SECRET_ACCESS_KEY"
prompt = "Enter the secret access key for the S3 object storage being used."
expires = 2023-08-16
owner = "alice"

[[secret]]
id = "access_key_id__bob"
name = "ACCESS_KEY_ID"
prompt = "Enter the access key id for the S3 object storage being used."
expires = 2023-08-16
owner = "bob"
[[secret]]
id = "secret_access_key__bob"
name = "SECRET_ACCESS_KEY"
prompt = "Enter the secret access key for the S3 object storage being used."
expires = 2023-08-16
owner = "bob"

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


### Template Directories ###

[[template]]
# The 'src' attribute should be a directory.
src = "example-templates"
# The prefix is used in front when rendering a path
# (example-templates/example-file.jinja) from the src directory:
# 'local:example-file.jinja'
prefix = "local"

# The chillbox python script includes some templates at the 'chillbox' prefix
# and 'chillbox-scripts'.
# 'chillbox-scripts:' contains common scripts that chillbox uses.
# 'chillbox:' has other general templates like user-data scripts.


### Path Files and Directories ###

# Define each path for files that need to be uploaded to the server.
# The 'id' attribute is required and needs to be unique.
# The 'src' attribute is the source of the file or directory relative to this
# configuration file. It can also be set to a template if it has a prefix.
# Use the 'dest' attribute to set the destination where it will be uploaded to
# on the server.
# The 'owner' attribute is only required when the 'sensitive' attribute is true.
# If the owner is defined; the file will only be uploaded if the owner matches
# the current user.
# The 'context' can be set to provide more variables other than the 'env' and
# 'secret' values.

# Copies these files from the host machine to the archive.
[[path]]
id = "example-readme"
src = "README.md"
dest = "/example/sub/README.md"

[[path]]
id = "stream-nginx-conf"
src = "chillbox:stream.nginx.conf.jinja"
dest = "/etc/nginx/conf.d/example-stream.nginx.conf"
render = true
[path.context]
domains = ["abc.example.com"]

# A path can set the 'sensitive' attribute to 'true' to encrypt that file when
# uploading it. The 'dest' path will then be appended to the CHILLBOX_PATH_SENSITIVE
# value which defaults to /var/lib/chillbox/path_sensitive/. This example shows a typical
# use case where the s3 credentials are being encrypted after they are rendered
# from that s3-credentials.jinja template. The template references the
# ACCESS_KEY_ID and SECRET_ACCESS_KEY secrets. The encrypted file will be
# written to /var/lib/chillbox/path_sensitive/alice/home/alice/.aws/credentials
# (path joined from CHILLBOX_PATH_SENSITIVE, OWNER, and DEST).
# 
# The 'owner' attribute is required if setting 'sensitive' to true. The file
# will not be uploaded if the current user does not match the owner.
[[path]]
id = "s3-credentials-example-for-alice"
src = "chillbox:s3-credentials.jinja"
dest = "/home/alice/.aws/credentials"
sensitive = true
owner = "alice"
render = true
[path.context]
AWS_PROFILE = "example-profile"

[[path]]
id = "s3-credentials-example-for-bob"
src = "chillbox:s3-credentials.jinja"
dest = "/home/bob/.aws/credentials"
sensitive = true
owner = "bob"
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

# Set the owner of the server. The owner should always have access.
owner = "alice"

# An optional 'login-users' list can be set to allow other users access to the
# server. For this example, bob is not on the list. Poor bob.
login-users = [ "alice" ]

# Specify which secrets will be included by their id. Each secret will be
# encrypted and uploaded to the set 'append-dest' location
# (CHILLBOX_PATH_SECRETS/USER/APPEND_DEST).
secrets = [ "example_secret", "example_secret_file" ]

# Specify which paths will be included by their id. Any path that does not have
# 'sensitive' attribute set to true will be directly uploaded to the set 'dest'
# location. Any sensitive paths will be encrypted and uploaded to
# CHILLBOX_PATH_SENSITIVE/OWNER/DEST location.
remote-files = [
  "stream-nginx-conf",
  "bootstrap-stream-nginx-server.sh",
  "s3-credentials-example-for-alice",
]
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
# Includes 'chillbox_user' object with the current user data. Useful to get the
# chillbox_user.public_ssh_key, chillbox_user.name, and chillbox_user.password_hash
# Includes 'chillbox_server' object with the server data. Useful to loop over
# chillbox_server.login-users or chillbox_server.name.
something = "example"

# Depending on the user-data template being used, the jinja include directive
# can be set to first use a variable for a template to include.
nft_script = "local:example.nft"

# Can also override the 'env' variables like this, but this would only be for
# the user-data script that gets rendered.
ENVIRONMENT = "development"

# Example of server that has both alice and bob as users that should be able to
# access it.
[[server]]
ip = "122.3.4.5"
name = "example-web-server-for-bob"
owner = "alice"
login-users = [ "alice", "bob" ]
secrets = [ "example_secret" ]
remote-files = [ 
  "chillbox-nginx-conf",
  "s3-credentials-example-for-alice",
  "s3-credentials-example-for-bob",
]
```
