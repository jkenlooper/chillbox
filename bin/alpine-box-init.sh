#!/usr/bin/env sh

addgroup dev
adduser -G dev -D dev

apk add openssh-server-pam

cat <<SSHD_CONFIG > /etc/ssh/sshd_config
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys
KbdInteractiveAuthentication no
PasswordAuthentication no
PermitRootLogin no
# Default is yes
PubkeyAuthentication yes
UsePAM yes
SSHD_CONFIG

mkdir -p /home/dev/.ssh
wget https://github.com/jkenlooper.keys -O - | tee -a /home/dev/.ssh/authorized_keys
chown -R dev:dev /home/dev/.ssh
chmod -R 700 /home/dev/.ssh
chmod -R 644 /home/dev/.ssh/authorized_keys

apk add doas
# TODO: update /etc/doas.d/doas.conf
# permit nopass dev as root cmd ls

# Cloud-Init script

export immutable_bucket_name="chillboximmutable"
export IMMUTABLE_BUCKET_NAME="chillboximmutable"
export artifact_bucket_name="chillboxartifact"
export ARTIFACT_BUCKET_NAME="chillboxartifact"
export endpoint_url="http://10.0.0.145:9000"
export S3_ENDPOINT_URL=http://10.0.0.145:9000
export S3_ARTIFACT_ENDPOINT_URL=http://10.0.0.145:9000
export AWS_ACCESS_KEY_ID=localvagrantaccesskey
export AWS_SECRET_ACCESS_KEY="localvagrantsecretkey1234"
export chillbox_artifact=chillbox.0.0.1-alpha.1.tar.gz
export CHILLBOX_SERVER_NAME=10.0.0.192

apk update
#vim /etc/ssh/sshd_config
sshd -t
rc-service sshd restart

apk update
apk add sed attr grep

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

# Support s6 init scripts.
# Only if not using container s6-overlay and using openrc instead.
apk add s6 s6-portable-utils
rc-update add s6-svscan boot

# TODO: How to enable and start this openrc service?
cat <<PURR > /etc/init.d/chill-$slugname
#!/sbin/openrc-run
name="chill-$slugname"
description="chill-$slugname"
supervisor=s6
s6_service_path=/etc/services.d/chill-$slugname
depend() {
  need s6-svscan net localmount
  after firewall
}
start_pre() {
  if [ ! -L "${RC_SVC_DIR}/s6-scan/${name}" ]; then
    ln -s "/etc/services.d/${name}" "${RC_SVCDIR}/s6-scan/${name}"
  fi
}
PURR
chmod +x /etc/init.d/chill-$slugname

# service configuration file?
# /etc/conf.d/chill-$slugname

rc-update add chill-$slugname default

mkdir -p /etc/services.d/chill-$slugname

cat <<MEOW > /etc/services.d/chill-$slugname/run
#!/bin/execlineb -P
cd $slugdir/chill
s6-env CHILL_HOST=localhost
s6-env CHILL_PORT=5000
s6-env CHILL_MEDIA_PATH=/media/
s6-env CHILL_THEME_STATIC_PATH=/theme/$version/
s6-env CHILL_DESIGN_TOKENS_HOST=/design-tokens/$version/
/usr/local/bin/chill serve
MEOW
chmod +x /etc/services.d/chill-jengalaxyart/run

cd $slugdir
# install site root dir
mkdir -p $slugdir/nginx/root
mkdir -p /srv/$slugname
mv $slugdir/nginx/root /srv/$slugname/
chown -R nginx:nginx /srv/$slugname/
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


#chown -R nginx:nginx /etc/chillbox/templates/
mkdir -p /srv/chillbox
chown -R nginx:nginx /srv/chillbox/
mkdir -p /var/cache/nginx
chown -R nginx:nginx /var/cache/nginx
mkdir -p /var/log/nginx/
mkdir -p /var/log/nginx/chillbox/
chown -R nginx:nginx /var/log/nginx/chillbox/
rm -rf /etc/nginx/conf.d/
mkdir -p /etc/nginx/conf.d/
chown -R nginx:nginx /etc/nginx/conf.d/
source /etc/chillbox/site_env_vars
for template_path in /etc/chillbox/templates/*.nginx.conf.template; do
  template_file=$(basename $template_path)
  envsubst "$(cat /etc/chillbox/site_env_names)" < $template_path > /etc/nginx/conf.d/${template_file%.template}
done
chown -R nginx:nginx /etc/nginx/conf.d/
# No test when building
#nginx -t

rc-update add nginx default
rc-service nginx start
