
task :default => :test

desc "Run only unit tests by default"
task :test => 'test:unit'

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
include Rake::DSL

namespace :test do
  Rake::TestTask.new(:unit) do |test|
    test.libs << %w{ lib test }
    test.pattern = 'test/unit/*_test.rb'
    test.verbose = true
  end
  
  Rake::TestTask.new(:integration) do |test|
    test.libs << %w{ lib test }
    test.pattern = 'test/integration/*_test.rb'
    test.verbose = true
  end
  
  desc "Run all tests, including integration tests"
  task :all => [ :unit, :integration ]
end

desc "Start game"
task :run do
    exec "bundle exec ruby -Ilib -Ilib/grelok lib/grelok.rb"
end
task :start => :run

desc "Run console (== irb) with current bundler environment"
task :console do
    exec "irb -Ilib -rrapidshare"
end
task :irb => :console
