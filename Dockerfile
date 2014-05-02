FROM ubuntu:trusty

RUN apt-get update

# Install ruby-2.1.1
RUN apt-get build-dep -y ruby2.0
RUN apt-get install -y git curl

RUN git clone https://github.com/sstephenson/ruby-build.git /ruby-build

ENV PATH /ruby-build/bin:$PATH
# Patch for readline because of breaked compatibility at current version
RUN curl -fsSL https://gist.github.com/mislav/a18b9d7f0dc5b9efc162.txt | ruby-build --patch 2.1.1 /usr/local
RUN gem install bundler

# Install kusabana
RUN mkdir /kusabana
WORKDIR /kusabana

# Add Gemfile and run bundle install
RUN apt-get install -y libsasl2-dev
ADD ./Gemfile /kusabana/
RUN bundle install

# Add any other file
RUN mv Gemfile.lock Gemfile.lock.tmp
ADD . /kusabana/
RUN mv Gemfile.lock.tmp Gemfile.lock

EXPOSE 9292
CMD ["bundle", "exec", "rake", "start"]
