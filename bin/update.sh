
# download new sites/*site.json files from s3
# Check version on each and skip if currently deployed
# Stop and remove if not existing
# Create new ones
# Update to new versions

# All the site.json is stored in a separate git repo

# Add an endpoint to chillbox nginx that will trigger the update.sh script.
# Create a webhook on the site.json repo that triggers the chillbox endpoint to
# do the update.
