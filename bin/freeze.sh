
# For each site check if archive version has been made.
# if no archive version then create with wget

wget
  --no-host-directories \
  --save-headers \
  --recursive \
  --level=inf \
  --timestamping \
  --convert-links \
  --page-requisites \
  -e robots=off \
  http://jengalaxyart.test:8083

# Upload archive version files to S3


# Update cloudformation template to have cloudfront point to S3 bucket


