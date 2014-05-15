#coding: utf-8
require 'spec_helper'

describe Kusabana::Logger do
  let(:env) { Kusabana::Environment.new(rules, config) }
  let(:rules) { [] }
  let(:logger) { Kusabana::Logger.new(STDOUT, 1, env) }

  describe '#req' do
    after { logger.req(hoge: 'fuga') }
    it { expect(logger).to receive(:info).with(hoge: 'fuga', type: 'req') }
  end

  describe '#res' do
    after { logger.res(hoge: 'fuga') }
    it { expect(logger).to receive(:info).with(hoge: 'fuga', type: 'res') }
  end
end
