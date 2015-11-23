ROOT_DIR = File.expand_path(File.dirname(__FILE__))

require 'rubygems' rescue nil
require 'rake'
require 'rspec/core/rake_task'

task :default => :spec

desc "Run all specs in spec directory."
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--options', "\"#{ROOT_DIR}/spec/spec.opts\""]
end

desc "Run benchmarks"
RSpec::Core::RakeTask.new(:benchmark) do |t|
  t.rspec_opts = ['--options', "\"#{ROOT_DIR}/spec/spec.opts\""]
  t.pattern = 'spec/*_benchmark.rb'
end
