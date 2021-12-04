# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"


  config.vm.define "chill_box", primary: true do |chill_box|
    chill_box.vm.hostname = "chillbox"

    chill_box.vm.network "forwarded_port", guest: 80, host: 38713, auto_correct: false
    chill_box.vm.network "forwarded_port", guest: 9000, host: 38714, auto_correct: false
    chill_box.vm.network "forwarded_port", guest: 9001, host: 38715, auto_correct: false

    chill_box.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end

    chill_box.trigger.after :up do |trigger|
      trigger.info = "Checking status of running services"
      trigger.on_error = :continue
      trigger.run_remote = {inline: <<-SHELL
        bash -c 'nginx -t;
        systemctl is-active nginx;'
      SHELL
      }
    end


    chill_box.vm.provision "shell-minio-alias-config", type: "shell", inline: <<-SHELL
    mkdir -p /root/.mc
    cat <<-'HERE' > /root/.mc/config.json
{
  "version": "10",
  "aliases": {
    "local": {
            "url": "http://localhost:9000",
            "accessKey": "llama",
            "secretKey": "chill*llamallama",
            "api": "s3v4",
            "path": "auto"
    }
  }
}
HERE
    SHELL

    chill_box.vm.provision "shell-install-minio-conf", type: "shell", inline: <<-SHELL
    adduser minio-user --disabled-login --disabled-password --gecos ""

    mkdir -p /var/lib/minio
    chown -R minio-user:minio-user /var/lib/minio
    mkdir -p /etc/systemd/system/minio.service.d
    cat <<-'HERE' > /etc/default/minio
MINIO_VOLUMES=/var/lib/minio
PORT=9000
MINIO_ROOT_USER=llama
MINIO_ROOT_PASSWORD=chill*llamallama
MINIO_OPTS="--console-address ':9001'"
HERE

    cd $(mktemp -d)
    #https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20211124231933.0.0_amd64.deb
    curl https://dl.min.io/server/minio/release/linux-amd64/minio_20211124231933.0.0_amd64.deb -o minio.deb
    sudo apt-get install ./minio.deb
    sudo systemctl start minio

    SHELL

    chill_box.vm.provision "shell-setup-minio", type: "shell", inline: <<-SHELL
    curl https://dl.min.io/client/mc/release/linux-amd64/mc \
      --create-dirs \
      -o /usr/local/bin/mc
    chmod +x /usr/local/bin/mc

    mc admin user add local localvagrantaccesskey localvagrantsecretkey1234
    mc mb --ignore-existing local/chillboximmutable
    mc mb --ignore-existing local/chillboxartifact

    SHELL

    chill_box.vm.provision "bin-install-latest-stable-nginx", type: "shell", path: "bin/install-latest-stable-nginx.sh"
    chill_box.vm.provision "bin-setup", type: "shell", path: "bin/setup.sh"


    chill_box.vm.provision "shell-install-nginx-conf", type: "shell", inline: <<-SHELL
    cp /vagrant/nginx.conf /etc/nginx/nginx.conf
    cp /vagrant/default.nginx.conf /etc/nginx/conf.d/default.conf
    rm -rf /etc/nginx/templates/
    mkdir -p /etc/nginx/templates/
    chown -R nginx:nginx /etc/nginx/templates/
    rm -rf /etc/nginx/conf.d/
    mkdir -p /etc/nginx/conf.d/
    chown -R nginx:nginx /etc/nginx/conf.d/
    cp -r /vagrant/templates/* /etc/nginx/templates/

    # Render the nginx conf templates using envsubst
    export NGINX_HOST=localhost
    export uri='$uri'
    export S3_ENDPOINT_URL='http://localhost:9000'
    for template_path in /etc/nginx/templates/*.nginx.conf.template; do
      template_file=$(basename $template_path)
      envsubst < $template_path > /etc/nginx/conf.d/${template_file%.template}
    done
    chown -R nginx:nginx /etc/nginx/conf.d/

    mkdir -p /srv/chillbox
    chown -R nginx:nginx /srv/chillbox/

    mkdir -p /var/cache/nginx
    chown -R nginx:nginx /var/cache/nginx
    mkdir -p /var/log/nginx/
    mkdir -p /var/log/nginx/chillbox/
    chown -R nginx:nginx /var/log/nginx/chillbox/

    # TODO: set environment variables in the nginx service which will be used
    # for conf in the templates directory.
    # /etc/systemd/system/nginx.service.d/override.conf
    mkdir -p /etc/systemd/system/nginx.service.d
    cat <<-'NGINX_CHILL_BOX_OVERRIDE' > /etc/systemd/system/nginx.service.d/chill_box.conf
    [Service]

    Environment="SOMETHING=astring"
    Environment="ANOTHER_THING=1234"

    Environment="S3_ENDPOINT_URL=http://localhost:9000"

NGINX_CHILL_BOX_OVERRIDE

    nginx -t
    systemctl daemon-reload
    systemctl start nginx
    systemctl reload nginx
    SHELL

    chill_box.vm.provision "bin-init-sites", type: "shell", path: "bin/init-sites.sh" do |s|
      s.env = {
        S3_ENDPOINT_URL: "http://localhost:9000"
      }
    end

  end

  # Disable the default /vagrant shared folder
  # Not disabling the /vagrant synced folder since ansible_local depends on it.
  config.vm.synced_folder ".", "/vagrant", disabled: false

end
