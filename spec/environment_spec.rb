#coding: utf-8
require 'spec_helper'

describe Kusabana::Environment do
  let(:env) { Kusabana::Environment.new(rules, config) }
  let(:rules) { [] }
  let(:session) { {} }
  let(:session_name) { UUID::generate :compact }
  before { env.sessions[session_name] = session }

  describe '#remote' do
    let(:remote) { env.remote(session_name) }
    let(:session) { {path: path} }

    context 'when receiving path will be matched' do
      let(:path) { '/fuga/fugafuga.html' }
      
      it { expect(remote).to eq(env.config['es']['remotes'][1]) }
    end

    context 'when receiving path will not be matched' do
      let(:path) { '/foo/bar.html' }
      
      it { expect(remote).to eq(env.config['es']['remotes'][0]) }
    end
  end
end
