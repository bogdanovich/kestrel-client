require 'spec_helper'

describe Siberite::Config do
  before do
    # to sniff namespace foo_space
    Siberite::Config.config['foo_space']['development']['connect_timeout'] = 8
  end

  describe "load" do
    it "loads a yaml file" do
      Siberite::Config.config = nil
      lambda { Siberite::Config.default }.should raise_error

      Siberite::Config.load TEST_CONFIG_FILE
      lambda { Siberite::Config.default }.should_not raise_error
    end
  end

  shared_examples_for "config getters" do
    it "returns a tuple of [servers, options]" do
      config = @configurer.call
      config.should be_a(Array)

      [String, Array].should include(config.first.class)
      config.last.should be_a(Hash)

      config.last.keys.map{|k| k.class }.uniq.should == [Symbol]
    end

    it "defaults to development enviroment" do
      @configurer.call.last[:server_failure_limit].should == 10 # development options should pull 10 from defaults
    end

    it "returns config for the specified environment" do
      Siberite::Config.environment = :production
      @configurer.call.last[:server_failure_limit].should == 4 # production is set to 4
    end
  end

  describe "namespace" do
    before { @configurer = lambda { Siberite::Config.namespace(:foo_space) } }

    it_should_behave_like "config getters"

    it "returns args for Siberite::Client.new for the appropriate namespace" do
      Siberite::Config.foo_space.last[:connect_timeout].should == 8
    end

    it "is aliased to method_missing" do
      Siberite::Config.foo_space.should == Siberite::Config.namespace(:foo_space)
    end
  end

  describe "default" do
    before { @configurer = lambda { Siberite::Config.default } }

    it_should_behave_like "config getters"
  end

  describe "new_client" do
    it "returns a Siberite::Client instance" do
      client = Siberite::Config.new_client
      client.should be_a(Siberite::Client)
    end

    it "can take a namespace" do
      client = Siberite::Config.new_client(:foo_space)
      client.should be_a(Siberite::Client)
      client.options[:connect_timeout].should == 8
    end
  end
end
