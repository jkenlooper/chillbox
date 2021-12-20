#!/usr/bin/env sh

# Cloud-Init script

immutable_bucket_name="chillboximmutable"
artifact_bucket_name="chillboxartifact"
endpoint_url="http://10.0.0.145:9000"
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

mkdir -p /etc/nginx/templates && cd /etc/nginx/templates
tar -x -f $tmp_chillbox_artifact templates/chillbox.nginx.conf.template

mkdir -p /etc/chillbox && cd /etc/chillbox
tar -x -f $tmp_chillbox_artifact sites


echo "export CHILLBOX_SERVER_NAME=$CHILLBOX_SERVER_NAME" >> /tmp/site_env_vars
echo '$CHILLBOX_SERVER_NAME' >> /tmp/site_env_names
