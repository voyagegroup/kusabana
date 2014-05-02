FROM ubuntu:trusty

RUN apt-get update
RUN apt-get install -y build-essential ruby2.0 ruby2.0-dev

RUN gem2.0 install bundler

RUN mkdir /kusabana
WORKDIR /kusabana

ADD ./Gemfile /kusabana
RUN bundle install

RUN mv Gemfile.lock Gemfile.lock.tmp
ADD . /kusabana
RUN mv Gemfile.lock.tmp Gemfile.lock

EXPOSE 9292
CMD ['bundle', 'exec', 'rake', 'start']
