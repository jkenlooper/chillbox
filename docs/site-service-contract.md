
# Site Service Contract

Stateless

## Flask Service Template

## Chill Service Template

All database tables are managed by chill and should be stored in the
chill-data.yaml file.

Required files that are needed.

- chill-data.yaml
- site.cfg (Default for chill)
- 

export ARTIFACT_BUCKET_NAME="${artifact_bucket_name}"
export AWS_PROFILE=chillbox_object_storage
export CHILLBOX_ARTIFACT="${chillbox_artifact}"
export CHILLBOX_SERVER_NAME="${chillbox_server_name}"
export CHILLBOX_SERVER_PORT=80
export IMMUTABLE_BUCKET_DOMAIN_NAME="${immutable_bucket_domain_name}"
export IMMUTABLE_BUCKET_NAME="${immutable_bucket_name}"
export ACME_SERVER="letsencrypt_test"
export S3_ENDPOINT_URL="${s3_endpoint_url}"
export SERVER_NAME="sitejsonplaceholder-server_name"
export SERVER_PORT=80
export SITES_ARTIFACT="${sites_artifact}"
export SLUGNAME="sitejsonplaceholder-slugname"
export TECH_EMAIL="${tech_email}"
export VERSION="sitejsonplaceholder-version"
