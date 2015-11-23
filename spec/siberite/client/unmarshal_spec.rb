require 'spec_helper'

describe Siberite::Client::Unmarshal do
  describe "Instance Methods" do
    before do
      @raw_client = Siberite::Client.new(*Siberite::Config.default)
      @client = Siberite::Client::Unmarshal.new(@raw_client)
    end

    describe "#get" do
      it "integrates" do
        @client.set('a_queue', "foo")
        @client.get('a_queue').should == 'foo'
      end

      it "unmarshals marshaled objects" do
        test_object = {:a => 1, :b => [1, 2, 3]}
        mock(@raw_client).get('a_queue', :raw => true) { Marshal.dump(test_object) }
        @client.get('a_queue').should == test_object
      end

      it "does not unmarshal when raw is true" do
        test_object = {:a => 1, :b => [1, 2, 3]}
        mock(@raw_client).get('a_queue', :raw => true) { Marshal.dump(test_object) }
        @client.get('a_queue', :raw => true).should == Marshal.dump(test_object)
      end

      it "passes through objects" do
        test_object = Object.new
        mock(@raw_client).get('a_queue', :raw => true) { test_object }
        @client.get('a_queue').should == test_object
      end

      it "passes through strings" do
        mock(@raw_client).get('a_queue', :raw => true) { "I am not marshaled" }
        @client.get('a_queue').should == "I am not marshaled"
      end
    end

    describe "#isMarshaled" do
      it "should foo" do
        @client.is_marshaled?("foo").should be_falsey
        @client.is_marshaled?(Marshal.dump("foo")).should be_truthy
        @client.is_marshaled?(Marshal.dump("foo")).should be_truthy

        @client.is_marshaled?({}).should be_falsey
        @client.is_marshaled?(Marshal.dump({})).should be_truthy
        @client.is_marshaled?(Marshal.dump({})).should be_truthy

        @client.is_marshaled?(BadObject.new).should be_falsey
        @client.is_marshaled?(Marshal.dump(BadObject.new)).should be_truthy
        @client.is_marshaled?(Marshal.dump(BadObject.new)).should be_truthy
      end
    end
  end
end

class BadObject
  def to_s
    raise Exception
  end
end

module Marshal
  def self.load_with_constantize(source, loaded_constants = [])
    self.load(source)
  end
end
