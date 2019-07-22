#!/usr/bin/env sh

set -ex

OS="$(grep '^ID=' /etc/os-release | sed 's/ID=\(.*\)/\1/')"
DOCKER_USER=${DOCKER_USER:-hammer}
DOCKER_UID=${DOCKER_UID:-888}


common_run() {
  BUNDLE_CACHE_ALL=true
  BUNDLE_CLEAN=true
  BUNDLE_SUPPRESS_INSTALL_USING_MESSAGES=true

  wget -O- https://github.com/CMeza99/katello-cvmanager/tarball/${KCV_COMMIT:-master}| tar x -zC /tmp
  KCV_SOURCE="$(find /tmp -type d -maxdepth 1 -name \*katello-cvmanager\*)"
  cd "${KCV_SOURCE}"
  gem install builder
  gem build --force cvmanager.gemspec
  mkdir -p /tmp/repo/gems
  mv *.gem /tmp/repo/gems
  cd /tmp/repo
  gem generate_index

  cd /home/hammer
  bundle install
  chown -R hammer:hammer /home/hammer

  su ${DOCKER_USER} -c '
    export CONFIG_PATH="${HOME}/.hammer"
    mkdir -p "${CONFIG_PATH}/cli.modules.d/"
    mkdir -m 700 "${CONFIG_PATH}/sessions"
    ln -s $(gem contents hammer_cli | grep -F "cli_config.template.yml") ${CONFIG_PATH}/cli_config.yml
    for g in $(gem list | grep -Eo "hammer_cli_(foreman|katello).* "); do
      for f in $(gem contents ${g} | grep -F ".yml"); do
        ln -s "${f}" "${CONFIG_PATH}/cli.modules.d/"
      done
    done
    '

  rm -rf -- "${KCV_SOURCE}" /tmp/repo /usr/local/bundle/cache/*
}


if [ "${OS}" = 'debian' ]; then
  useradd -ms /bin/sh -u ${DOCKER_UID} -UG users ${DOCKER_USER}
  apt-get -qq update

  DEBIAN_FRONTEND=noninteractive apt-get -yqq --no-install-suggests --no-install-recommends install \
    git \
    libc6-dev gcc g++ make \
     > /dev/null

  common_run

  DEBIAN_FRONTEND=noninteractive apt-get -yqq --no-install-suggests --no-install-recommends purge
    libc6-dev gcc g++ make \
     > /dev/null
  rm -rf -- /var/lib/apt/lists/* /var/cache/apt/*

elif [ "${OS}" = 'alpine' ]; then
  addgroup -g ${DOCKER_UID} ${DOCKER_USER}
  adduser -s /bin/sh -u ${DOCKER_UID} -DG ${DOCKER_USER} ${DOCKER_USER}
  addgroup ${DOCKER_USER} users

  ln -s /var/cache/apk /etc/apk/cache
  apk  add \
    git \
    > /dev/null
  apk  add --virtual .build-dependencies \
    libc-dev gcc g++ make \
    > /dev/null

  common_run

  apk --purge del .build-dependencies
  rm -f -- /etc/apk/cache /var/apk/cache/*

else
  printf '\nERROR: Could not determine Linux disto.\n'
  exit 1
fi
