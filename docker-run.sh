#!/usr/bin/env sh

set -ex

OS="$(grep '^ID=' /etc/os-release | sed 's/ID=\(.*\)/\1/')"
DOCKER_USER=${DOCKER_USER:-hammer}
DOCKER_UID=${DOCKER_UID:-888}


common_run() {
  cd /tmp
  git clone https://github.com/CMeza99/katello-cvmanager.git
  cd katello-cvmanager
  gem build cvmanager.gemspec
  mkdir -p /tmp/repo/gems
  cp *.gem /tmp/repo/gems
  gem install builder
  cd /tmp/repo
  gem generate_index

  cd /home/hammer
  bundle --no-cache --clean --system
  chown -R hammer:hammer /home/hammer
  cd -
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
  apk add --no-cache \
    git \
    > /dev/null
  apk add --no-cache --virtual .build-dependencies \
    libc-dev gcc g++ make \
    > /dev/null
  common_run
  apk del --no-cache .build-dependencies

else
  printf '\nERROR: Could not determine Linux disto.\n'
  exit 1
fi
