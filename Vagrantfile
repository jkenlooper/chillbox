# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"


  config.vm.define "chill_box", primary: true do |chill_box|
    chill_box.vm.hostname = "chillbox"
    chill_box.vm.network :private_network, ip: "192.168.120.224", auto_config: true, hostname: true

    chill_box.vm.network "forwarded_port", guest: 80, host: 38713, auto_correct: false

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

    chill_box.vm.provision "bin-install-latest-stable-nginx", type: "shell", path: "bin/install-latest-stable-nginx.sh"
    chill_box.vm.provision "bin-setup", type: "shell", path: "bin/setup.sh"

    chill_box.vm.provision "shell-install-nginx-conf", type: "shell", inline: <<-SHELL
    cp /vagrant/nginx.conf /etc/nginx/nginx.conf
    cp /vagrant/default.nginx.conf /etc/nginx/conf.d/default.conf
    mkdir -p /etc/nginx/templates/
    chown -R nginx:nginx /etc/nginx/templates/
    mkdir -p /etc/nginx/conf.d/
    chown -R nginx:nginx /etc/nginx/conf.d/
    cp -r /vagrant/templates/* /etc/nginx/templates/

    # Render the nginx conf templates using envsubst
    export NGINX_HOST=localhost
    export uri='$uri'
    export S3_ENDPOINT_URL='http://10.0.2.2:9000'
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

    # 10.0.2.2 is the Vagrant host IP from the prespective of the guest.
    # Port 9000 is the default port for the S3 minio server.
    Environment="S3_ENDPOINT_URL=http://10.0.2.2:9000"

NGINX_CHILL_BOX_OVERRIDE

    nginx -t
    systemctl daemon-reload
    systemctl start nginx
    systemctl reload nginx
    SHELL

  end

  # Disable the default /vagrant shared folder
  # Not disabling the /vagrant synced folder since ansible_local depends on it.
  config.vm.synced_folder ".", "/vagrant", disabled: false

end
