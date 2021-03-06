#!/usr/bin/env sh

set -o errexit

# UPKEEP due: "2022-10-08" label: "Update aws-cli" interval: "+3 months"
# https://gist.github.com/jkenlooper/78dcbea2cfe74231a7971d8d66fa4bd0
# Based on https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
AWS_CLI_VERSION="2.7.14"

# Prevent reinstalling aws-cli by checking the version.
current_aws_version="$(command -v aws > /dev/null && aws --version | cut -f1 -d ' ' || printf "")"
if [ "$current_aws_version" = "aws-cli/$AWS_CLI_VERSION" ]; then
  # Output the version here in case other scripts depend on this output.
  aws --version
  exit
fi

apk add gnupg gnupg-dirmngr

tmp_aws_cli_install_dir=$(mktemp -d)
cleanup() {
  test -n "$tmp_aws_cli_install_dir" \
    && test -d "$tmp_aws_cli_install_dir" \
    && rm -r "$tmp_aws_cli_install_dir"
}
trap cleanup EXIT

install_aws_cli_v2() {
	echo "
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4WIQT7
Xbd/1cEYuAURraimMQrMRnJHXAUCXYKvtQIbAwUJB4TOAAULCQgHAgYVCgkICwIE
FgIDAQIeAQIXgAAKCRCmMQrMRnJHXJIXEAChLUIkg80uPUkGjE3jejvQSA1aWuAM
yzy6fdpdlRUz6M6nmsUhOExjVIvibEJpzK5mhuSZ4lb0vJ2ZUPgCv4zs2nBd7BGJ
MxKiWgBReGvTdqZ0SzyYH4PYCJSE732x/Fw9hfnh1dMTXNcrQXzwOmmFNNegG0Ox
au+VnpcR5Kz3smiTrIwZbRudo1ijhCYPQ7t5CMp9kjC6bObvy1hSIg2xNbMAN/Do
ikebAl36uA6Y/Uczjj3GxZW4ZWeFirMidKbtqvUz2y0UFszobjiBSqZZHCreC34B
hw9bFNpuWC/0SrXgohdsc6vK50pDGdV5kM2qo9tMQ/izsAwTh/d/GzZv8H4lV9eO
tEis+EpR497PaxKKh9tJf0N6Q1YLRHof5xePZtOIlS3gfvsH5hXA3HJ9yIxb8T0H
QYmVr3aIUes20i6meI3fuV36VFupwfrTKaL7VXnsrK2fq5cRvyJLNzXucg0WAjPF
RrAGLzY7nP1xeg1a0aeP+pdsqjqlPJom8OCWc1+6DWbg0jsC74WoesAqgBItODMB
rsal1y/q+bPzpsnWjzHV8+1/EtZmSc8ZUGSJOPkfC7hObnfkl18h+1QtKTjZme4d
H17gsBJr+opwJw/Zio2LMjQBOqlm3K1A4zFTh7wBC7He6KPQea1p2XAMgtvATtNe
YLZATHZKTJyiqA==
=vYOk
-----END PGP PUBLIC KEY BLOCK-----
" | gpg --import

	wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip.sig" -O "$tmp_aws_cli_install_dir/awscliv2.sig"
	wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -O "$tmp_aws_cli_install_dir/awscliv2.zip"

	gpg --verify "$tmp_aws_cli_install_dir/awscliv2.sig" "$tmp_aws_cli_install_dir/awscliv2.zip"

	unzip "$tmp_aws_cli_install_dir/awscliv2.zip" -d "$tmp_aws_cli_install_dir"

	"$tmp_aws_cli_install_dir/aws/install" -i "/usr/local/src/aws-cli" -b "/usr/local/src/aws-cli/v2/bin" --update
	ln -sf /usr/local/src/aws-cli/v2/bin/aws /usr/local/bin/aws
}


# The aws-cli binaries requires glibc libraries and alpine linux is based on 'musl glibc'.
# Thanks to https://github.com/aws/aws-cli/issues/4685#issuecomment-615872019
GLIBC_VER=2.31-r0
# install glibc compatibility for alpine
apk --no-cache add \
        binutils
wget -q https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -O /etc/apk/keys/sgerrand.rsa.pub
wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-${GLIBC_VER}.apk -O "$tmp_aws_cli_install_dir/glibc-${GLIBC_VER}.apk"
wget -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VER}/glibc-bin-${GLIBC_VER}.apk -O "$tmp_aws_cli_install_dir/glibc-bin-${GLIBC_VER}.apk"

apk add --no-cache \
		 "$tmp_aws_cli_install_dir/glibc-${GLIBC_VER}.apk" \
		 "$tmp_aws_cli_install_dir/glibc-bin-${GLIBC_VER}.apk"

install_aws_cli_v2

rm -rf \
		/usr/local/aws-cli/v2/*/dist/aws_completer \
		/usr/local/aws-cli/v2/*/dist/awscli/data/ac.index \
		/usr/local/aws-cli/v2/*/dist/awscli/examples

# Output the version here as a smoke test.
aws --version
