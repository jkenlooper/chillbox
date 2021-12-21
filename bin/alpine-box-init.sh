#!/usr/bin/env sh

# Cloud-Init script

immutable_bucket_name="chillboximmutable"
IMMUTABLE_BUCKET_NAME="chillboximmutable"
artifact_bucket_name="chillboxartifact"
ARTIFACT_BUCKET_NAME="chillboxartifact"
endpoint_url="http://10.0.0.145:9000"
S3_ENDPOINT_URL=http://10.0.0.145:9000
S3_ARTIFACT_ENDPOINT_URL=http://10.0.0.145:9000
AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
export AWS_SECRET_ACCESS_KEY
chillbox_artifact=chillbox.0.0.1-alpha.1.tar.gz
CHILLBOX_SERVER_NAME=10.0.0.192

apk update
apk add vim
#vim /etc/ssh/sshd_config
sshd -t
rc-service sshd restart

cat > /etc/apk/repositories << EOF; $(echo)
http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/main
http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/community
EOF

apk update
apk add sed attr dialog dialog-doc bash bash-doc bash-completion grep grep-doc
apk add util-linux util-linux-doc pciutils usbutils binutils findutils readline
apk add mandoc man-pages lsof lsof-doc less less-doc nano nano-doc curl curl-doc
export PAGER=less

apk add --no-cache gnupg gnupg-dirmngr
apk add nginx
apk add gcc python3 python3-dev libffi-dev build-base musl-dev make git sqlite
ln -s /usr/bin/python3 /usr/bin/python
python --version
mkdir -p /usr/local/src/chill-venv
cd /usr/local/src/chill-venv/
git clone https://github.com/jkenlooper/chill.git ./
python -m venv .
source bin/activate
pip install --upgrade pip wheel
pip install --disable-pip-version-check -r requirements.txt
pip install .

export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
ln -s /usr/local/src/chill-venv/bin/chill /usr/local/bin/chill
chill --version

apk add jq aws-cli
apk add gettext

# TODO: Fetch chill-box artifact files from s3
# nginx.conf, default.nginx.conf, templates, site/
tmp_chillbox_artifact=$(mktemp)
aws \
  --endpoint-url "$endpoint_url" \
  s3 cp s3://${artifact_bucket_name}/chillbox/$chillbox_artifact \
  $tmp_chillbox_artifact

cd /etc/nginx
tar -o -x -f $tmp_chillbox_artifact nginx.conf

mkdir -p /etc/nginx/conf.d && cd /etc/nginx/conf.d
tar -x -f $tmp_chillbox_artifact default.nginx.conf

mkdir -p /etc/chillbox && cd /etc/chillbox
tar -x -f $tmp_chillbox_artifact templates sites

echo "export CHILLBOX_SERVER_NAME=$CHILLBOX_SERVER_NAME" >> /etc/chillbox/site_env_vars
echo '$CHILLBOX_SERVER_NAME' >> /etc/chillbox/site_env_names


export slugname="jengalaxyart"
export server_name="jengalaxyart.test"

mkdir -p /usr/local/src/
cd /usr/local/src/

echo "access key id $AWS_ACCESS_KEY_ID"
aws --version
export version="$(jq -r '.version' /etc/chillbox/sites/$slugname.site.json)"

jq -r \
  '.env[] | "export " + .name + "=" + .value' /etc/chillbox/sites/$slugname.site.json \
    | envsubst '$S3_ENDPOINT_URL $IMMUTABLE_BUCKET_NAME $slugname $version $server_name' >> /etc/chillbox/site_env_vars
jq -r '.env[] | "$" + .name' /etc/chillbox/sites/$slugname.site.json | xargs >> /etc/chillbox/site_env_names
echo /etc/chillbox/site_env_vars
cat /etc/chillbox/site_env_vars
echo /etc/chillbox/site_env_names
cat /etc/chillbox/site_env_names

tmp_artifact=$(mktemp)
aws --endpoint-url "$S3_ARTIFACT_ENDPOINT_URL" \
  s3 cp s3://$ARTIFACT_BUCKET_NAME/${slugname}/$slugname-$version.artifact.tar.gz \
  $tmp_artifact
tar -x -f $tmp_artifact
rm $tmp_artifact
slugdir=$PWD/$slugname

# init chill
cd $slugdir/chill
chill initdb
chill load --yaml chill-data.yaml

# TODO: this is s6 specific. Should use openrc here instead?
mkdir -p /etc/services.d/chill-$slugname

cat <<MEOW > /etc/services.d/chill-$slugname/run
#!/usr/bin/execlineb -P
cd $slugdir/chill
s6-env CHILL_HOST=localhost
s6-env CHILL_PORT=5000
s6-env CHILL_MEDIA_PATH=/media/
s6-env CHILL_THEME_STATIC_PATH=/theme/$version/
s6-env CHILL_DESIGN_TOKENS_HOST=/design-tokens/$version/
/usr/local/bin/chill serve
MEOW

cd $slugdir
# install site root dir
mkdir -p $slugdir/nginx/root
mkdir -p /srv/$slugname
mv $slugdir/nginx/root /srv/$slugname/
chown -R nginx:ngnix /srv/$slugname/
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/$slugname/
chown -R nginx:nginx /var/log/nginx/$slugname/
# Install nginx templates that start with slugname
mv $slugdir/nginx/templates/$slugname*.nginx.conf.template /etc/chillbox/templates/
rm -rf $slugdir/nginx
# Set version
mkdir -p /srv/chillbox/$slugname
chown -R nginx:nginx /srv/chillbox/$slugname/
echo "$version" > /srv/chillbox/$slugname/version.txt
SITE_INIT
