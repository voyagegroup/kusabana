#coding: utf-8
require 'spec_helper'

describe Kusabana::Rule do
  let(:method) { 'GET' }
  let(:pattern) { /^\/hoge\/.+$/ }
  let(:expired) { 10 }
  let(:rule) { Kusabana::Rule.new(method, pattern, expired) }

  describe '#add_modifier' do
    let(:modifier) { Kusabana::QueryModifier.new(/hoge/) {|query| query} }
    after { rule.add_modifier(modifier) }

    it { expect(rule.instance_variable_get(:@modifiers)).to receive(:<<).with(modifier) }
  end

  describe '#match' do
    context 'when receive with arguments will be matched' do
      it { expect(rule.match(method, '/hoge/fuga')).to be_true }
    end

    context 'when receive with arguments will be not matched' do
      context 'because of method' do
        let(:path) { '/hoge/fuga' }
        it { expect(rule.match('POST', path)).to be_false }

        it do
          rule.match('POST', path)
          expect(rule.instance_variable_get(:@path)).to_not eq(path)
        end
      end

      context 'because of path' do
        let(:path) { '/fuga/hoge' }
        it { expect(rule.match(method, path)).to be_false }

        it do
          rule.match(method, path)
          expect(rule.instance_variable_get(:@path)).to_not eq(path)
        end
      end
    end
  end

  describe '#modify' do
    let(:query) { '{"hoge": "fugafuga"}' }
    let(:modified) { '{"hoge" : "fuga"}' }
    let(:path) { '/foo/bar' }
    before do
      rule.instance_variable_set(:@path, path)
      allow(rule).to receive(:scan_query).with(Oj.load(query, mode: :compat)).and_return(modified)
    end

    it { expect(rule.modify(query)).to eq([Oj.dump(modified, mode: :compat), "#{method}::#{path}::#{modified.hash}"]) }
  end

  describe '#scan_query' do
    context 'when query is Hash' do
      let(:query) { {"hoge" => "fuga", "foo" => "bar"} }
      let(:modifier) { Kusabana::QueryModifier.new(/^hoge$/) {|query| query} }
      after { rule.scan_query(query) }
      before { rule.instance_variable_set(:@modifiers, [modifier]) }

      it { expect(query).to receive(:inject).with({}) }

      context "when receive query will be matched" do
        it { expect(modifier).to receive(:modify).with('fuga') }
      end

      context "when receive query will be matched" do
        let(:query) { {"hogehoge" => "fuga", "foo" => "bar"} }
        it { expect(modifier).to_not receive(:modify).with('fuga') }
      end
    end

    context 'when query is Array' do
      let(:query) { ['foo', 'bar', 'baz'] }
      after { rule.scan_query(query) }

      it { expect(query).to receive(:map) }
    end
  end
end

describe Kusabana::QueryModifier do
  let(:modifier) { Kusabana::QueryModifier.new(/hoge/) {|query| query} }
  describe '#modify' do
    let(:query) { 'fuga' }
    after { modifier.modify(query) }

    it { expect(modifier.instance_variable_get(:@block)).to receive(:call).with(query) }
  end
end
