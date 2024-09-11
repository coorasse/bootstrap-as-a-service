# Dockerfile

FROM ruby:3.3.5

WORKDIR /app
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock
ADD .ruby-version /app/.ruby-version

RUN bundle install

ADD . /app

RUN bundle install && \
    apt-get update -qq && \
    apt-get install curl -y


EXPOSE 4567

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]
