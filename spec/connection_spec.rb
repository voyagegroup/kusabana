#coding: utf-8
require 'spec_helper'

describe Kusabana::Connection do
  let(:config) { YAML.load_file("config.yml") }
  let(:rules) { [] }
  let(:proxy) { Kusabana::Proxy.new(rules, config) }
  let(:connection) { Kusabana::Connection.new({}, config) }

  describe '#on_data' do
    let(:request) { "GET / HTTP/1.1\r\n\r\n" }
    before { connection.instance_variable_set(:@req_parser, '') }
    after { connection.send(:on_data).call(request) }

    it { expect(connection.instance_variable_get(:@req_buffer)).to receive(:<<).with(request) }
    it { expect(connection.instance_variable_get(:@req_parser)).to receive(:<<).with(request) }
  end

  describe '#on_parse_request_body' do
    let(:callback) { connection.send(:on_parse_request_body) }
    let(:parser) { HTTP::Parser.new }
    after { parser << request }
    before { parser.on_body = callback }

    context 'when receive request with body' do
      let(:body) { 'hoge' }
      let(:request) { "POST / HTTP/1.1\r\nContent-Length: 4\r\n\r\n#{body}" }

      it { expect(callback).to receive(:call).with(body) }
      it { expect(connection.instance_variable_get(:@req_body)).to receive(:<<).with(body) }
    end

    context 'when receive request without body' do
      let(:request) { "GET / HTTP/1.1\r\n\r\n" }

      it { expect(callback).to_not receive(:call) }
    end
  end

  describe '#on_parse_request', valid: true do
    let(:callback) { connection.send(:on_parse_request) }
    let(:parser) { HTTP::Parser.new }
    before { parser.on_message_complete = callback }
    after { parser << request }
    let(:request) { "GET / HTTP/1.1\r\n\r\n" }

    it { expect(callback).to receive(:call) }
  end

  describe '#on_parse_response', valid: true do
    let(:callback) { connection.send(:on_parse_response, nil) }
    let(:parser) { HTTP::Parser.new }
    before { parser.on_message_complete = callback }
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }
    after { parser << response }

    it { expect(callback).to receive(:call) }
  end

  describe '#on_response' do
    let(:response) { "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nhoge" }
    let(:uuid) { UUID::generate :compact }
    let(:session) { {res_buffer: '', res_parser: HTTP::Parser.new} }
    before do
      connection.instance_variable_get(:@sessions)[uuid] = session
      connection.send(:on_response).call(uuid ,response)
    end

    it { expect(session[:res_buffer]).to eq(response) }
    it { expect(session[:res_parser].status_code).to eq(200) }
  end
end
