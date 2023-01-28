TODO: Use litestream to automatically backup sqlite databases that the services use.

TODO: Errors should be sent to stderr.
```
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}
if ! do_something; then
  err "Unable to do_something"
  exit 1
fi
```

TODO: Clean up docker build noise from running the scripts. Only output the docker build logs if there was an error.

TODO: When a Chillbox server is deleted, the associated s3 objects that were encrypted with the Chillbox server's public key should also be removed.

TODO: Rename Artifact Bucket to Private Bucket as it is more generic that way.
TODO: Rename Immutable Bucket to Public Bucket as it is more generic that way.
