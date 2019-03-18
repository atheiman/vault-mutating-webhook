# Build a basic passenger standalone environment
FROM ruby:2-alpine
RUN apk update && \
    apk add alpine-sdk openssl-dev curl-dev pcre-dev && \
    gem install passenger --no-document && \
    passenger-config install-standalone-runtime --connect-timeout 120 --idle-timeout 120 && \
    passenger-config validate-install && \
    mkdir /app
# Add app specific customizations
WORKDIR /app
COPY Gemfile* config.ru *.rb ./
RUN bundle install --without test
# Run passenger
ENTRYPOINT ["passenger", "start"]
