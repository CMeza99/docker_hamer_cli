ARG RUBY=ruby
ARG RUBY_VER=latest
ARG IMG_VARIANT=
FROM ${RUBY}:${RUBY_VER}${IMG_VARIANT}

# Diabling of cahce  must be set as env var because `--no-cache` does not work as expected.
# See https://github.com/bundler/bundler/issues/6680
ENV BUNDLE_CLEAN=true \
    BUNDLE_CACHE_ALL=false

COPY docker-run.sh /opt/
COPY Gemfile /home/hammer/

RUN /opt/docker-run.sh

WORKDIR /home/hammer
USER hammer

ENTRYPOINT [ "hammer" ]
CMD [ "shell" ]
