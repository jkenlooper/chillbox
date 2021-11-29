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

    mkdir -p /var/cache/nginx
    chown -R nginx:nginx /var/cache/nginx
    mkdir -p /var/log/nginx/
    mkdir -p /var/log/nginx/chill_box/
    chown -R nginx:nginx /var/log/nginx/chill_box/

    # TODO: set environment variables in the nginx service which will be used
    # for conf in the templates directory.
    # /etc/systemd/system/nginx.service.d/override.conf
    mkdir -p /etc/systemd/system/nginx.service.d
    cat <<-'NGINX_CHILL_BOX_OVERRIDE' > /etc/systemd/system/nginx.service.d/chill_box.conf
    [Service]
    Environment="SOMETHING=astring"
    Environment="ANOTHER_THING=1234"
    Environment="S3_ENDPOINT_URL=http://192.168.120.226:38714"
NGINX_CHILL_BOX_OVERRIDE

    nginx -t
    systemctl daemon-reload
    systemctl start nginx
    systemctl reload nginx
    SHELL

  end


  config.vm.define "s3fake" do |s3fake|
    s3fake.vm.hostname = "s3fake"
    s3fake.vm.network :private_network, ip: "192.168.120.226", auto_config: true, hostname: true
    s3fake.vm.network "forwarded_port", guest: 4568, host: 38714, auto_correct: false

    s3fake.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end

    s3fake.vm.provision "shell-install-s3rver", type: "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y nodejs npm

    adduser s3rver --disabled-login --disabled-password --gecos "" || echo 'user exists already?'

    su --command '
      cd /home/s3rver
      cat <<-PACKAGEJSON > package.json
{
  "name": "_",
  "version": "1.0.0",
  "description": "Fake S3 server",
  "scripts": {
    "start": "s3rver --directory /home/s3rver/files --address s3fake --no-vhost-buckets --configure-bucket chum"
  },
  "dependencies": {
    "s3rver": "3.7.1"
  }
}
PACKAGEJSON

      mkdir -p /home/s3rver/files
      npm install --no-save --ignore-scripts 2> /dev/null
    ' s3rver

    cat <<-'SERVICE_INSTALL' > /etc/systemd/system/s3rver.service
[Unit]
Description=Fake S3 Server
After=multi-user.target

[Service]
Type=exec
User=s3rver
Group=s3rver
WorkingDirectory=/home/s3rver
ExecStart=npm start
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE_INSTALL
    systemctl daemon-reload
    systemctl start s3rver
    systemctl enable s3rver

    SHELL

    s3fake.vm.post_up_message = <<-POST_UP_MESSAGE
      Fake S3 Server is running in the private network with a 'chum' bucket.
      Use these AWS credentials to connect to it:
        Access Key Id: "S3RVER"
        Secret Access Key: "S3RVER"

      # Example of uploading test-file and fetching it both with `aws s3 cp` and `curl`.
      echo 'testing' > test-file
      aws s3 cp --endpoint-url=http://192.168.120.226:38714 test-file s3://chum/
      aws s3 cp --endpoint-url=http://192.168.120.226:38714 s3://chum/test-file get-test-file
      curl http://192.168.120.226:38714/chum/test-file
    POST_UP_MESSAGE

  end

  # Disable the default /vagrant shared folder
  # Not disabling the /vagrant synced folder since ansible_local depends on it.
  config.vm.synced_folder ".", "/vagrant", disabled: false

end
