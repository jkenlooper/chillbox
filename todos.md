TODO: Use litestream to automatically backup sqlite databases that the services use.
TODO: Automatically upload any redis snapshots to s3.

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

TODO: When a Chillbox server is deleted, the associated s3 objects that were encrypted with the Chillbox server's public key should also be removed.

TODO: Rename Artifact Bucket to Private Bucket as it is more generic that way.
TODO: Rename Immutable Bucket to Public Bucket as it is more generic that way.
