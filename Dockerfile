# Dockerfile

FROM ruby:3.3.5

WORKDIR /app
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock

RUN bundle install

ADD . /app

RUN bundle install

EXPOSE 4567

CMD ["ruby", "app.rb"]
