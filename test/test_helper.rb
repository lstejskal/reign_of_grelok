require 'rubygems'
require 'test/unit'

require 'shoulda'
require 'turn'
require 'mocha/setup'

# do no run game main loop 
ENV['GRELOK_REQUIRE_ONLY'] = "1"

require 'grelok'

class Test::Unit::TestCase

  def read_fixture(filename, extension = 'txt')
    # add extension to file unless it already has it
    filename += ".#{extension}" unless (filename =~ /\.\w+$/)
    
    File.read File.expand_path(File.dirname(__FILE__) + "/fixtures/#{filename}")
  end

  # general setup, can be overriden or extended in specific tests
  #
  def setup
  end

end
