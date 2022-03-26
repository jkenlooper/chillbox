import os

from flask import Flask


def create_app(test_config=None):
    # create and configure the app
    app = Flask(__name__, instance_path=os.environ.get("FLASK_INSTANCE_PATH", None), instance_relative_config=False)

    # Set the defaults
    app.config.from_mapping(
        SERVER_NAME="site1.test"
    )

    if test_config is None:
        # Override the defaults with the instance config when not testing
        app.config.from_pyfile('config.py', silent=False)

        # Follow OpenFaaS philosophy and don't set secrets in environment
        # variables. Read secrets from the file system.
        # The SECRETS_CONFIG is usually
        # /var/lib/site1/secrets/api.cfg
        app.config.from_envvar('SECRETS_CONFIG', silent=False)
        if not app.config.get('SALT'):
            raise ValueError(f"No SALT set in {os.environ.get('SECRETS_CONFIG')}.")
        if not app.config.get('AWS_ACCESS_KEY_ID'):
            raise ValueError(f"No AWS_ACCESS_KEY_ID set in {os.environ.get('SECRETS_CONFIG')}.")
        if not app.config.get('AWS_SECRET_ACCESS_KEY'):
            raise ValueError(f"No AWS_SECRET_ACCESS_KEY set in {os.environ.get('SECRETS_CONFIG')}.")

        if not app.config.get('S3_ENDPOINT_URL'):
            raise ValueError("No S3_ENDPOINT_URL set in environment.")
        if not app.config.get('ARTIFACT_BUCKET_NAME'):
            raise ValueError("No ARTIFACT_BUCKET_NAME set in environment.")
        if not app.config.get('IMMUTABLE_BUCKET_NAME'):
            raise ValueError("No IMMUTABLE_BUCKET_NAME set in environment.")

    else:
        # load the test config if passed in
        app.config.from_mapping(test_config)

    # ensure the instance folder exists
    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

    app.logger.debug("Adding /healthcheck route")

    @app.route('/healthcheck')
    def healthcheck():
        return 'Okay'

    app.logger.debug("Create app done")
    return app
