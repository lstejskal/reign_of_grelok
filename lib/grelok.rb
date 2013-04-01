
require 'yaml'
require 'readline'

require 'core_extensions'

# don't exit when you get an interrupt signal (Crtl+C)
trap('INT', 'SIG_IGN')

# PS: to update the game data 
# system "ruby ./wrap_yaml_files.rb"
require 'grelok/game_data'

require 'grelok/reign_of_grelok'
require "grelok/version"
