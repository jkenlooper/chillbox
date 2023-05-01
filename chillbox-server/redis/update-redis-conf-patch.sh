#!/usr/bin/env sh

set -o errexit

script_dir="$(dirname "$(realpath "$0")")"
script_name="$(basename "$0")"

echo "INFO $script_name: Updating redis.conf.patch file."

# UPKEEP due: "2023-08-09" label: "Redis 7.0 configuration" interval: "+6 months"
# https://raw.githubusercontent.com/redis/redis/7.0/00-RELEASENOTES
# https://download.redis.io/releases/
non_patched_redis_conf="$script_dir/non-patched-redis-7_0.conf"
if [ ! -e "$non_patched_redis_conf" ]; then
    wget -O "$non_patched_redis_conf" "https://raw.githubusercontent.com/redis/redis/7.0/redis.conf"
fi

# Avoid needing to store the whole config file by recreating it.
patch -i "$script_dir/redis.conf.patch" -o "$script_dir/redis.conf" "$non_patched_redis_conf"

# Prevent manual changes by keeping it read only.
chmod u+w "$script_dir/redis.conf.patch"
diff -w -u --label "$(basename "$non_patched_redis_conf")" --label redis.conf "$non_patched_redis_conf" "$script_dir/redis.conf" > "$script_dir/redis.conf.patch" || printf ""
chmod a-w "$script_dir/redis.conf.patch"

echo "INFO $script_name: Verifying that patch file can be applied."
tmp_conf="$(mktemp)"
patch -i "$script_dir/redis.conf.patch" -o "$tmp_conf" "$non_patched_redis_conf"
diff -w "$script_dir/redis.conf" "$tmp_conf"
rm -f "$tmp_conf"
