# creates grelok_data.rb file containing yml files converted into hashes

require 'yaml'

yaml_filenames = Dir.entries(Dir.pwd).grep(/\.yml$/).collect { |f| f.gsub(/\..+$/,'') }

grelok_data = File.open('game_data.rb', 'w')
grelok_data.puts "\nclass GameData\n" #  attr_accessor #{yaml_filenames.collect { |f| ":#{f}" }.join(", ")}\n\n"

yaml_filenames.each do |yaml_filename|
  grelok_data.puts "\n  #{yaml_filename.upcase} = " + YAML.load(File.read("#{yaml_filename}.yml")).inspect
end

grelok_data.puts "\nend"
grelok_data.close
