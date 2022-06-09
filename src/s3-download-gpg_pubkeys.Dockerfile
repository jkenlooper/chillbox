ARG WORKSPACE=development
FROM chillbox-s3-wrapper-$WORKSPACE:latest

COPY --chown=dev:dev terraform-bin/_download_gpg_pubkeys_as_dev_user.sh bin/
COPY --chown=dev:dev terraform-bin/_download_gpg_pubkeys.sh bin/

CMD ["/usr/local/src/s3-wrapper/bin/_download_gpg_pubkeys.sh"]
