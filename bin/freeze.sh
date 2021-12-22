
# For each site check if archive version has been made.
# if no archive version then create with wget

  #--save-headers \
wget \
  --no-host-directories \
  --recursive \
  --level=inf \
  --timestamping \
  --convert-links \
  --page-requisites \
  -e robots=off \
  http://jengalaxyart.test:9081

# Upload archive version files to S3


# Update cloudformation template to have cloudfront point to S3 bucket


