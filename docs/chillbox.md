chillbox artifact 

- bootstrap-chillbox-init-credentials.sh generated from src/terraform/020-chillbox/bootstrap-chillbox-init-credentials.sh.tftpl
    - bin/chillbox-init.sh
        - bin/install-chill.sh
        - bin/install-service-dependencies.sh
        - bin/install-acme.sh
        - bin/generate-chillbox-key.sh
        - bin/init-nginx.sh
        - bin/site-init.sh
            - bin/upload-immutable-files-from-artifact.sh
            - bin/stop-site-services.sh
            - bin/site-init-nginx-service.sh
            - bin/site-init-service-object.sh
        - bin/reload-templates.sh
        - bin/issue-and-install-letsencrypt-certs.sh

The bin/chillbox-init.sh script will extract the chillbox artifact files to the following
paths:

- bin/ -> /etc/chillbox/bin/
- nginx/templates/ -> /etc/chillbox/templates/
- nginx/nginx.conf -> /etc/nginx/nginx.conf
- nginx/default.nginx.conf -> /etc/nginx/conf.d/default.nginx.conf

The bin/init-nginx.sh script creates these directories if they don't already
exist:

- /srv/chillbox/
- /var/cache/nginx/
- /var/log/nginx/
- /var/log/nginx/chillbox/
- /etc/nginx/conf.d/

And removes any initial /etc/nginx/conf.d/*.conf excluding the
default.nginx.conf.

The bin/site-init.sh script

Extracts the sites artifact to the /etc/chillbox/sites/ directory.

Creates these directories where `$slugname` is each site's name.

- /etc/chillbox/sites/
- /usr/local/src/$slugname
- /usr/local/src/$slugname/nginx/root
- /srv/$slugname
- /var/log/nginx/$slugname/
- /srv/chillbox/$slugname

Executes the following scripts:

- bin/upload-immutable-files-from-artifact.sh
- bin/stop-site-services.sh
- bin/site-init-nginx-service.sh
- bin/site-init-service-object.sh

Adds the crontab entry for each site if a crontab was defined in the sites
config.
