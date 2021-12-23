
# For each site check if archive version has been made.
# if no archive version then create with wget

for url in \
  http://jengalaxyart.test:9081 \
  http://jengalaxyart.test:9081/notfound.html \
  http://jengalaxyart.test:9081/error.html \
  http://jengalaxyart.test:9081/maintenance.html \
  http://jengalaxyart.test:9081/robots.txt \
  ; do
wget \
  --no-host-directories \
  --recursive \
  --level=inf \
  --timestamping \
  --convert-links \
  --page-requisites \
  -e robots=off \
  $url
done

# Upload archive version files to S3


# Update cloudformation template to have cloudfront point to S3 bucket


