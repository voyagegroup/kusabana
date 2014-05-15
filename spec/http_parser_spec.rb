#coding: utf-8
require 'spec_helper'

describe Kusabana::RequestParser do
  let(:rules) { [] }
  let(:env) { Kusabana::Environment.new(rules, config) }
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
    let(:request) { "GET / HTTP/1.1\r\n\r\n#{body}" }
    let(:callback) { parser.send(:on_parse_request) }
    let(:session_name) { UUID.generate :compact }

    before { allow(UUID).to receive(:generate).and_return(session_name) }
    before { parser.instance_variable_set(:@buffer, request) }
    after { callback.call }

    context 'when matched' do
      let(:rule) { Kusabana::Rule.new('', //, 0) }
      let(:rules) { [rule] }
      before { allow(rule).to receive(:match).and_return(true) }

      context 'and hit cache' do
        let(:cache) { UUID.generate :compact }
        before { allow(env.cache).to receive(:get_or_nil).and_return(cache) }
        before { allow(conn).to receive(:send_data).with(cache) }

        it { expect(conn).to receive(:send_data).with(cache) }
        it { expect(env.sessions).to receive(:delete).with(session_name) }
      end

      context 'and hit no cache' do
        let(:modified_body) { UUID.generate :compact }
        let(:modified_request) { "GET / HTTP/1.1\r\n\r\n#{modified_body}" }
        before { allow(env.cache).to receive(:get_or_nil).and_return(nil) }
        before { allow(rule).to receive(:modify).and_return(modified_body) }

        it { expect(conn).to receive(:relay).with(session_name, modified_request) }
      end
    end

    context 'when not matched' do
      it { expect(conn).to receive(:relay).with(session_name, request) }
    end
  end
end

describe Kusabana::ResponseParser do
  let(:rules) { [] }
  let(:env) { Kusabana::Environment.new(rules, config) }
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
    let(:session) { {} }
    let(:callback) { parser.send(:on_parse_response, session_name) }
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }

    before { env.sessions[session_name] = session }
    before  { allow(session).to receive(:[]).and_return(nil) }
    before  { allow(session).to receive(:[]).with(:start).and_return(0) }
    after { callback.call }

    context 'when matched' do
      let(:rule) { Kusabana::Rule.new('', //, 0) }

      before { parser.instance_variable_set(:@buffer, response) }
      before  { allow(session).to receive(:[]).with(:cache).and_return(true) }
      before  { allow(session).to receive(:[]).with(:rule).and_return(rule) }

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
      it { expect(env.cache).to_not receive(:set) }
    end

  describe '#<<' do
    let(:data) { "GET / HTTP/1.1\r\n\r\n" }
    before { parser.on_message_complete = -> {} }
    after { parser << data }

    it { expect(parser.instance_variable_get(:@buffer)).to receive(:<<).with(data) }
    end
  end
end

