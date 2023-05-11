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
   the 'current_user' to be set. Enter a user name or use the default based on
   who you are currently logged in as. After hitting enter it will show another
   message stating that the current_user has not been added to the chillbox
   configuration. Do that now by appending the below to the configuration file.

Add the current user to the bottom of chillbox.toml. Replace 'YOUR_CURRENT_USER'
with the current user you set earlier.

```toml
## Add to the bottom of chillbox.toml

[[user]]
name = "YOUR_CURRENT_USER"

```

6. Run the `chillbox init` command again. This time it will see that a user has
   been defined and the current user matches it. Chillbox uses GnuPG to encrypt
   the private asymmetric key that chillbox will generate. Since your local
   machine most likely doesn't already have a GPG key named 'hello-chillbox'; it
   will prompt you to create a new GPG key and set a password on it.


7. _TODO_ Continue tutorial here.

---

[TOML]: https://toml.io/en/
