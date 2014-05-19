#coding: utf-8
require 'spec_helper'

describe Kusabana::Connection do
  let(:env) { Kusabana::Environment.new(rules, config) }
  let(:rules) { [] }
  let(:conn) { Kusabana::Connection.new({}, env: env) }
  let(:session_name) { UUID::generate :compact }


  describe '#relay' do
    let(:data) { UUID::generate :compact }

    before { env.sessions[session_name] = {} }
    before { allow(conn).to receive(:server).and_return(EM::ProxyServer::Backend.new({})) }
    after { conn.send(:relay, session_name, data) }

    it { expect_any_instance_of(EM::ProxyServer::Backend).to receive(:send_data).with(data) }

    it do
      allow_any_instance_of(EM::ProxyServer::Backend).to receive(:send_data).with(data)
      expect(env.sessions[session_name]).to receive(:[]=)
    end
  end

  describe '#server' do
    after { conn.server(session_name) }

    it do
      allow(EM).to receive(:bind_connect).and_return(EM::ProxyServer::Backend.new({}))
      expect_any_instance_of(EM::ProxyServer::Backend).to receive(:comm_inactivity_timeout=)
    end
  end


  describe '#on_data' do
    let(:request) { "GET / HTTP/1.1\r\n\r\n" }
    after { conn.send(:on_data).call(request) }

    it { expect_any_instance_of(Kusabana::RequestParser).to receive(:<<).with(request) }
  end

  describe '#on_response' do
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }
    let(:parser) { HTTP::ResponseParser.new(session_name) }
    let(:session) { {res_parser: parser} }

    before { conn.instance_variable_get(:@env).sessions[session_name] = session }
    after { conn.send(:on_response).call(session_name, response) }

    it { expect(parser).to receive(:<<).with(response) }
  end
end
