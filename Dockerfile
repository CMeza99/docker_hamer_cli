ARG RUBY=ruby
ARG RUBY_VER=latest
ARG IMG_VARIANT=
FROM ${RUBY}:${RUBY_VER}${IMG_VARIANT}

COPY docker-run.sh /opt/
COPY Gemfile /home/hammer/

RUN /opt/docker-run.sh

WORKDIR /home/hammer
USER hammer

ENTRYPOINT [ "hammer" ]
CMD [ "shell" ]
