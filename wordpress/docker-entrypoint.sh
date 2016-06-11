#!/bin/bash
set -e

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
  : "${WORDPRESS_DB_HOST:=mysql}"
  # if we're linked to MySQL and thus have credentials already, let's use them
  : ${WORDPRESS_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}
  if [ "$WORDPRESS_DB_USER" = 'root' ]; then
    : ${WORDPRESS_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
  fi
  : ${WORDPRESS_DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
  : ${WORDPRESS_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-wordpress}}

  if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
    echo >&2 'error: missing required WORDPRESS_DB_PASSWORD environment variable'
    echo >&2 '  Did you forget to -e WORDPRESS_DB_PASSWORD=... ?'
    echo >&2
    echo >&2 '  (Also of interest might be WORDPRESS_DB_USER and WORDPRESS_DB_NAME.)'
    exit 1
  fi

  if ! [ -e index.php -a -e wp-includes/version.php ]; then
    echo >&2 "WordPress not found in $(pwd) - copying now..."
    if [ "$(ls -A)" ]; then
      echo >&2 "WARNING: $(pwd) is not empty - press Ctrl+C now if this is an error!"
      ( set -x; ls -A; sleep 10 )
    fi
    tar cf - --one-file-system -C /usr/src/wordpress . | tar xf -
    echo >&2 "Complete! WordPress has been successfully copied to $(pwd)"
    if [ ! -e .htaccess ]; then
      # NOTE: The "Indexes" option is disabled in the php:apache base image
      cat > .htaccess <<-'EOF'
        # BEGIN WordPress
        <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.php$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]
        </IfModule>
        # END WordPress

        # BEGIN php settings
        php_value max_execution_time  300
        php_value max_input_time      300
        php_value post_max_size       32M
        php_value upload_max_filesize 32M
        # END php settings
EOF
      chown www-data:www-data .htaccess
    fi
  fi

  # TODO handle WordPress upgrades magically in the same way, but only if wp-includes/version.php's $wp_version is less than /usr/src/wordpress/wp-includes/version.php's $wp_version

  # version 4.4.1 decided to switch to windows line endings, that breaks our seds and awks
  # https://github.com/docker-library/wordpress/issues/116
  # https://github.com/WordPress/WordPress/commit/1acedc542fba2482bab88ec70d4bea4b997a92e4
  sed -ri 's/\r\n|\r/\n/g' wp-config*

  if [ ! -e wp-config.php ]; then
    awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' wp-config-sample.php > wp-config.php <<'EOPHP'
// If we're behind a proxy server and using HTTPS, we need to alert Wordpress of that fact
// see also http://codex.wordpress.org/Administration_Over_SSL#Using_a_Reverse_Proxy
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
  $_SERVER['HTTPS'] = 'on';
  $_SERVER['SERVER_PORT'] = 443;
}

EOPHP
    chown www-data:www-data wp-config.php
  fi

  # see http://stackoverflow.com/a/2705678/433558
  sed_escape_lhs() {
    echo "$@" | sed 's/[]\/$*.^|[]/\\&/g'
  }
  sed_escape_rhs() {
    echo "$@" | sed 's/[\/&]/\\&/g'
  }
  php_escape() {
    php -r 'var_export(('$2') $argv[1]);' "$1"
  }
  set_config() {
    key="$1"
    value="$2"
    var_type="${3:-string}"
    start="(['\"])$(sed_escape_lhs "$key")\2\s*,"
    end="\);"
    if [ "${key:0:1}" = '$' ]; then
      start="^(\s*)$(sed_escape_lhs "$key")\s*="
      end=";"
    fi
    sed -ri "s/($start\s*).*($end)$/\1$(sed_escape_rhs "$(php_escape "$value" "$var_type")")\3/" wp-config.php
  }

  set_config 'DB_HOST' "$WORDPRESS_DB_HOST"
  set_config 'DB_USER' "$WORDPRESS_DB_USER"
  set_config 'DB_PASSWORD' "$WORDPRESS_DB_PASSWORD"
  set_config 'DB_NAME' "$WORDPRESS_DB_NAME"

  # allow any of these "Authentication Unique Keys and Salts." to be specified via
  # environment variables with a "WORDPRESS_" prefix (ie, "WORDPRESS_AUTH_KEY")
  UNIQUES=(
    AUTH_KEY
    SECURE_AUTH_KEY
    LOGGED_IN_KEY
    NONCE_KEY
    AUTH_SALT
    SECURE_AUTH_SALT
    LOGGED_IN_SALT
    NONCE_SALT
  )
  for unique in "${UNIQUES[@]}"; do
    eval unique_value=\$WORDPRESS_$unique
    if [ "$unique_value" ]; then
      set_config "$unique" "$unique_value"
    else
      # if not specified, let's generate a random value
      current_set="$(sed -rn "s/define\((([\'\"])$unique\2\s*,\s*)(['\"])(.*)\3\);/\4/p" wp-config.php)"
      if [ "$current_set" = 'put your unique phrase here' ]; then
        set_config "$unique" "$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)"
      fi
    fi
  done

  if [ "$WORDPRESS_TABLE_PREFIX" ]; then
    set_config '$table_prefix' "$WORDPRESS_TABLE_PREFIX"
  fi

  if [ "$WORDPRESS_DEBUG" ]; then
    set_config 'WP_DEBUG' 1 boolean
  fi

  : ${WORDPRESS_DB_CREATOR_PASSWORD:=$WORDPRESS_DB_PASSWORD}
  : ${WORDPRESS_DB_CREATOR_USER:=$WORDPRESS_DB_USER}

  TERM=dumb php -- \
    "$WORDPRESS_DB_HOST" \
    "$WORDPRESS_DB_USER" \
    "$WORDPRESS_DB_PASSWORD" \
    "$WORDPRESS_DB_NAME" \
    "$WORDPRESS_DB_CREATOR_USER" \
    "$WORDPRESS_DB_CREATOR_PASSWORD" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

$stderr = fopen('php://stderr', 'w');
$stdout = fopen('php://stdout', 'w');

$user = $argv[2];
$userpw = $argv[3];
$dbname = $argv[4];
$creator = $argv[5];
$creatorpw = $argv[6];

list($host, $port) = explode(':', $argv[1], 2);

$maxTries = 10;
do {
  fwrite($stdout, sprintf('Connecting as %s to %s.', $creator, $dbname));
  $mysql = new mysqli($host, $creator, $creatorpw, '', (int)$port);
  if ($mysql->connect_error) {
    fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
    --$maxTries;
    if ($maxTries <= 0) {
      exit(1);
    }
    sleep(3);
  }
} while ($mysql->connect_error);

$_creator = $mysql->real_escape_string($creator);
$_creatorpw = $mysql->real_escape_string($creatorpw);
$_dbname = $mysql->real_escape_string($dbname);
$_user = $mysql->real_escape_string($user);
$_userpw = $mysql->real_escape_string($userpw);

$sql_create_db = sprintf("CREATE DATABASE IF NOT EXISTS %s", $_dbname);
if (!$mysql->query($sql_create_db)) {
  fwrite($stderr, sprintf('Tried to run "%s", but got "%s."', $sql_create_db, $mysql->error));
  $mysql->close();
  exit(1);
}

$sql_create_user = sprintf("CREATE USER IF NOT EXISTS '%s'@'%%' IDENTIFIED BY '%s'", $_user, $_userpw);
if (!$mysql->query($sql_create_user)) {
  fwrite($stderr, sprintf('Tried to run "%s", but got "%s."', $sql_create_user, $mysql->error));
  $mysql->close();
  exit(1);
}

$sql_grant_user = sprintf("GRANT ALL ON %s.* TO '%s'@'%%'", $_dbname, $_user);
if (!$mysql->query($sql_grant_user)) {
  fwrite($stderr, sprintf('Tried to run "%s", but got "%s".', $sql_grant_user, $mysql->error));
  $mysql->close();
  exit(1);
}

$mysql->close();
EOPHP
fi

exec "$@"
