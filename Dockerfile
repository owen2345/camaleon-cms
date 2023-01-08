FROM ruby:3.1-slim as builder
RUN apt-get update && apt-get install curl gnupg build-essential libpq-dev -y
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq
RUN apt install yarn -y
RUN apt-get install imagemagick -y

RUN mkdir /app
WORKDIR /app

# Default port and web server command
EXPOSE 3000
CMD ["bundle exec rspec"]

##################################### (Development)
# install google chrome
RUN apt-get install wget -y
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
RUN apt-get -y update
RUN apt-get install -y google-chrome-stable

# install chromedriver
RUN apt-get install -yqq unzip
RUN wget -O /tmp/chromedriver.zip http://chromedriver.storage.googleapis.com/`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE`/chromedriver_linux64.zip
RUN unzip /tmp/chromedriver.zip chromedriver -d /usr/local/bin/

#COPY package.json yarn.lock /app/
#RUN yarn install
COPY Gemfile* camaleon_cms.gemspec /app/
COPY lib/camaleon_cms/version.rb /app/lib/camaleon_cms/
RUN bundle install --jobs 20 --retry 5
COPY . /app
