#coding: utf-8
require 'spec_helper'

describe Kusabana::Proxy do
  let(:config) { YAML.load_file("config.yml") }
  let(:rules) { [] }
  let(:proxy) { Kusabana::Proxy.new(rules, config) }

  context '#on_data' do
    let(:request) { "GET / HTTP/1.1\r\n\r\n" }

    context 'when called' do
      before { proxy.send(:on_data).call(request) }

      it { expect(proxy.instance_variable_get(:@req_buffer)).to eq(request) }
      it { expect(proxy.instance_variable_get(:@req_parser).http_method).to eq('GET') }
    end

    context 'when set for callback' do
      let(:conn) { EM::ProxyServer::Connection }
    end
  end

  context '#on_parse_request_body' do
    let(:callback) { proxy.send(:on_parse_request_body) }
    let(:parser) { proxy.instance_variable_get(:@req_parser) }
    before { parser.on_body = callback }
    after { parser << request }

    context 'when receive request with body' do
      let(:body) { 'hoge' }
      let(:request) { "POST / HTTP/1.1\r\nContent-Length: 4\r\n\r\n#{body}" }

      it { expect(callback).to receive(:call).with(body) }
      it { expect(proxy.instance_variable_get(:@req_body)).to receive(:<<).with(body) }
    end

    context 'when receive request without body' do
      let(:request) { "GET / HTTP/1.1\r\n\r\n" }

      it { expect(callback).to_not receive(:call) }
    end
  end

  context '#on_parse_request', valid: true do
    let(:callback) { proxy.send(:on_parse_request, nil) }
    let(:parser) { proxy.instance_variable_get(:@req_parser) }
    before { parser.on_message_complete = callback }
    after { parser << request }
    let(:request) { "GET / HTTP/1.1\r\n\r\n" }

    it { expect(callback).to receive(:call).and_return }
  end

  context '#on_parse_request', valid: true do
    let(:callback) { proxy.send(:on_parse_request, nil) }
    let(:parser) { proxy.instance_variable_get(:@res_parser) }
    before { parser.on_message_complete = callback }
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }
    after { parser << response }

    it { expect(callback).to receive(:call).and_return }
  end

  context '#on_response' do
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }
    before { proxy.send(:on_response).call('hoge' ,response) }

    it { expect(proxy.instance_variable_get(:@res_buffer)).to eq(response) }
    it { expect(proxy.instance_variable_get(:@res_parser).status_code).to eq(200) }
  end
end
