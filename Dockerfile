# Build a basic passenger standalone environment
FROM ruby:2-alpine
RUN apk update && \
    apk add alpine-sdk openssl-dev curl-dev pcre-dev && \
    gem install passenger --no-document && \
    passenger-config install-standalone-runtime --connect-timeout 120 --idle-timeout 120 && \
    passenger-config validate-install
# Add app specific customizations
COPY . /app
WORKDIR /app
RUN bundle install --without test
# Run passenger
ENTRYPOINT ["passenger", "start"]
