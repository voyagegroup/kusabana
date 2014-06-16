#coding: utf-8
require 'spec_helper'

describe Kusabana::RequestParser do
  let(:proxy) { Kusabana::Proxy.new(config) }
  let(:env) { Kusabana::Environment.new(proxy) }
  let(:conn) { Kusabana::Connection.new({}, env: env) }
  let(:parser) { Kusabana::RequestParser.new(env, conn) }

  describe '#<<' do
    let(:data) { "GET / HTTP/1.1\r\n\r\n" }
    before { parser.on_message_complete = -> {} }
    after { parser << data }

    it { expect(parser.instance_variable_get(:@buffer)).to receive(:<<).with(data) }
  end

  describe '#on_parse_request_body' do
    let(:callback) { parser.send(:on_parse_request_body) }
    let(:body) { UUID.generate :compact }
    after { callback.call(body) }

    it { expect(parser.instance_variable_get(:@body)).to receive(:<<).with(body) }
  end

  describe '#on_parse_request' do
    let(:body) { UUID.generate :compact }
    let(:callback) { parser.send(:on_parse_request) }
    let(:session_name) { UUID.generate :compact }
    let(:rule) { Kusabana::Rule.new('GET', /^\/hoge$/, 0) }

    before { allow(parser).to receive(:request_url).and_return('/hoge/hoge') }
    before { allow(parser).to receive(:http_method).and_return('GET') }
    before { allow(UUID).to receive(:generate).and_return(session_name) }
    before { parser.instance_variable_set(:@buffer, request) }
    after { callback.call }

    context 'when matched' do
      let(:request) { "GET /hoge/hoge HTTP/1.1\r\n\r\n#{body}" }
      before { proxy.set_rule('/hoge', [rule]) }

      context 'and hit cache' do
        let(:cache) { UUID.generate :compact }
        before { allow(env.cache).to receive(:get_or_nil) { cache } }

        it do
          expect(env.sessions).to receive(:delete).with(session_name)
          expect(conn).to receive(:send_data).with(cache)
        end
      end

      context 'and hit no cache' do
        let(:modified_body) { UUID.generate :compact }
        let(:modified_request) { "GET /hoge HTTP/1.1\r\n\r\n#{modified_body}" }
        before { allow(rule).to receive(:modify).and_return(modified_body) }

        it { expect(conn).to receive(:relay).with(session_name, modified_request) }
      end
    end

    context 'when not matched' do
      let(:request) { "GET /hoge/fuga HTTP/1.1\r\n\r\n#{body}" }
      it { expect(conn).to receive(:relay).with(session_name, request) }
    end
  end
end

describe Kusabana::ResponseParser do
  let(:proxy) { Kusabana::Proxy.new(config) }
  let(:env) { Kusabana::Environment.new(proxy) }
  let(:conn) { Kusabana::Connection.new({}, env: env) }
  let(:session_name) { UUID.generate :compact }
  let(:parser) { Kusabana::ResponseParser.new(env, session_name) }

  describe '#<<' do
    let(:data) { "GET / HTTP/1.1\r\n\r\n" }
    before { parser.on_message_complete = -> {} }
    after { parser << data }

    it { expect(parser.instance_variable_get(:@buffer)).to receive(:<<).with(data) }
  end

  describe '#on_parse_response', valid: true do
    let(:callback) { parser.send(:on_parse_response) }
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }
    let(:rule) { Kusabana::Rule.new('', //, 0) }

    before { env.sessions[session_name] = session }
    after { callback.call }

    context 'when matched' do
      let(:session) { {rule: rule, start: 0, cache: true} }
      before { parser.instance_variable_set(:@buffer, response) }

      context 'and request was success' do
        before  { allow(parser).to receive(:status_code).and_return(200) }
        it { expect(env.cache).to receive(:set).with(nil, response, 0) }
      end

      context "and request wasn't success" do
        before  { allow(parser).to receive(:status_code).and_return(404) }
        it { expect(env.cache).to_not receive(:set).with(nil, response, 0) }
      end
    end
    
    context 'when not matched' do
      let(:session) { {rule: rule, start: 0, cache: false} }
      it { expect(env.cache).to_not receive(:set) }
    end
  end

  describe '#<<' do
    let(:data) { "GET / HTTP/1.1\r\n\r\n" }
    before { parser.on_message_complete = -> {} }
    after { parser << data }

    it { expect(parser.instance_variable_get(:@buffer)).to receive(:<<).with(data) }
  end
end

