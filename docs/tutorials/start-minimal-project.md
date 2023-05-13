# Start a minimal project

1. Create an empty directory on the local machine where `chillbox` has been
installed. Name this empty project directory 'hello-chillbox' for this tutorial.
Perform the rest of the commands within this project directory (`cd hello-chillbox`).

2. Run the `chillbox init` command. Note that this will show an ERROR message
   about a missing configuration file.

3. Chillbox needs a configuration file. Create a file named 'chillbox.toml' in the
   project directory. This configuration file will be in the [TOML] format.

4. Not all settings are required for the chillbox configuration file. Add only
   the required ones:  "instance", "gpg-key", and "archive-directory". Copy and
   paste the below TOML snippet to the 'chillbox.toml' file.

```toml
## chillbox.toml

instance = "hello-chillbox"

gpg-key = "hello-chillbox"

# The directory to use to store the state files among other things.  This
# directory should not be included in source control. It is only useful to the
# current user.
archive-directory = ".chillbox"
```

5. Run the `chillbox init` command again. Note that this time it will prompt for
   the 'current_user' to be set. For this tutorial; enter 'alice' as the current
   user.  After hitting enter it will show another message stating that the
   current_user has not been added to the chillbox configuration. Do that now by
   appending the below to the configuration file.

Add the current user to the bottom of chillbox.toml.

```toml
## Add to the bottom of chillbox.toml

[[user]]
# Alice is the current user for this tutorial.
name = "alice"

```

6. Run the `chillbox init` command again. This time it will see that a user has
   been defined and the current user matches it (alice is the current user at
   this step in the tutorial). Chillbox uses [GnuPG] to encrypt the private
   asymmetric key that chillbox will generate. Since your local machine most
   likely doesn't already have a GPG key named 'hello-chillbox'; it will prompt
   you to create a new GPG key and set a password on it.

   It will also automatically create a private and public ssh key for this user.
   This is because no 'public_ssh_key' was set for 'alice' in the chillbox
   configuration file. The private ssh key is encrypted in the chillbox archive
   directory.

   A prompt to set a password for 'alice' will also happen at this point. Only
   the hash of this password is saved in the chillbox archive directory. It can
   be used when adding 'alice' to a server.

7. Persist the password_hash and public_ssh_key that was created for 'alice'.
   These are stored in the chillbox archive directory and can be viewed by using
   the `jq` command or just open the statefile.json in a text editor. Copy these
   from .chillbox/statefile.json and include them in the chillbox.toml for the
   'alice' user.

```toml
## Update just the 'alice' user in chillbox.toml

[[user]]
# Alice is the current user for this tutorial.
name = "alice"
password_hash = "copy/paste the '.current_user_data.password_hash' value from ./chillbox/statefile.json"
public_ssh_key = [
   "copy/paste the '.current_user_data.public_ssh_key[0]' value from ./chillbox/statefile.json"
]

```

8. Add another user named 'bob' to the chillbox.toml. Bob has shared his public
   ssh key with Alice, so it can also be set here. 

```toml
## Add to the bottom of chillbox.toml after the 'alice' user.

[[user]]
name = "bob"
public_ssh_key = "ssh-rsa AAA--not-a-real-public-ssh-key+This-is-just-for-the-tutorial== bob@example.com"

```

9. Alice has access to a secret value that will be needed on the server. Add a secret 
   in the chillbox.toml like this.

```toml
## Add to the bottom of chillbox.toml

[[secret]]
id = "favorite_color_for_alice"
name = "FAVORITE_COLOR"
prompt = "What... is your favorite color?"
owner = "alice"

```

10. Run the `chillbox init` command again. It will prompt Alice for that secret
    since she is the current user and the 'owner' is set to 'alice'. After
    entering the secret value (no characters will be shown); the secret is
    encrypted and stored in the chillbox archive directory.

11. Bob also has access to a secret that will need to be used on a server. Alice
   will not need to ask Bob for that secret, but can add a prompt for it in the
   chillbox.toml. This time the 'owner' will be set to 'bob'. This secret is
   only valid for a short time and so an 'expires' date is set.

```toml
## Add to the bottom of chillbox.toml

[[secret]]
id = "level_3_lunch_code"
name = "SECRET_LUNCH_CODE"
prompt = "Enter the lunch code for next week:"
owner = "bob"
expires = 2023-11-02

```

   Note that if `chillbox init` is run again it doesn't prompt Alice for that
   secret.

12. Other values that are not so secretive can be added as environment
    variables. Add some now by adding an 'env' section and key/values to the
    chillbox configuration file.

```toml
## Add to chillbox.toml

[env]
MENU = "breakfast"
THEME = "funny hats"

```

13. Chillbox can be used to load up these env variables with the 'output-env'
    subcommand. The 'output-env' will print out the temporary file that is
    created. Run this command to display them.

```bash
# Show the environment variables set with chillbox.
chillbox output-env | xargs cat

# Show the environment variables and secrets set with chillbox.
chillbox output-env --include-secrets | xargs cat
```

   Show the help for more information: `chillbox output-env --help`

14. Chillbox is mainly for setting up deployment scripts for servers. Define
    a 'server' in the chillbox configuration file with a fake 'ip' address for
    now.  A 'server.user-data' section is added with a template file defined.
    This will be how a user-data script can be created.

```toml
## Add to chillbox.toml

[[server]]
# Using the localhost for the tutorial.
ip = "127.0.0.1"
name = "hello-chillbox-example-server"
owner = "alice"

[server.user-data]
template = "tutorial:hello-chillbox-user-data.sh.jinja"

```

15. Run the `chillbox server-init` command to try creating the user-data script
    for that server. It will show an error since no template file was found.
    Create that template file now by creating a 'template-tutorial' directory
    and including the below contents to a file named
    'hello-chillbox-user-data.sh.jinja' within that directory. 


```jinja
#!/usr/bin/env sh

# Example user-data script for hello-chillbox tutorial.
# template-tutorial/hello-chillbox-user-data.sh.jinja

## Add user and set the password hash
# shellcheck disable=SC2016
useradd -m -U -p '{{ chillbox_user.password_hash }}' '{{ chillbox_user.name }}'

## Add the user's public ssh key.
mkdir -p '/home/{{ chillbox_user.name }}/.ssh'
cat <<'HERE_PUBLIC_SSH_KEYS' > '/home/{{ chillbox_user.name }}/.ssh/authorized_keys'
{{ chillbox_user["public_ssh_key"] | join('\n') }}
HERE_PUBLIC_SSH_KEYS

chown -R '{{ chillbox_user.name }}:{{ chillbox_user.name }}' '/home/{{ chillbox_user.name }}/.ssh'
chmod -R 700 '/home/{{ chillbox_user.name }}/.ssh'
chmod -R 644 '/home/{{ chillbox_user.name }}/.ssh/authorized_keys'



```

16. Custom templates need to be defined in the chillbox configuration as well.
    Add a 'template' for the 'tutorial' prefix that will use the
    'template-tutorial' directory as the 'src' (source).

```toml
## Add to chillbox.toml

[[template]]
src = "template-tutorial"
prefix = "tutorial"
```

17. Run `chillbox server-init` again. This time it will find that template to
    use when creating the user-data file. It renders this file with the values
    found in the environment and saves it to the chillbox archive directory.
    View the rendered user-data file now with a text editor or with the `cat`
    command.

```bash
cat .chillbox/server/hello-chillbox-example-server/user-data
```

The rendered user-data script will have the necessary commands to add the
current user (alice) to the server. This user-data script could be used when
provisioning a new server.

18. ...WIP 

---

[TOML]: https://toml.io/en/
[GnuPG]: https://www.gnupg.org/
