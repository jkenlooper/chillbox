FROM chillbox-s3-wrapper:latest

COPY --chown=dev:dev terraform-bin/_upload_encrypted_secrets.sh bin/
COPY --chown=dev:dev terraform-bin/_upload_encrypted_secrets_as_dev_user.sh bin/


CMD ["/usr/local/src/s3-wrapper/bin/_upload_encrypted_secrets.sh"]
