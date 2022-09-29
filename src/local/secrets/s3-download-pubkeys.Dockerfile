FROM chillbox-s3-wrapper:latest

COPY --chown=dev:dev _download_pubkeys_as_dev_user.sh bin/
COPY --chown=dev:dev _download_pubkeys.sh bin/

CMD ["/usr/local/src/s3-wrapper/bin/_download_pubkeys.sh"]
