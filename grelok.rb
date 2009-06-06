  
# The story originates from Fallout 3 minigame - Reign of Grelok beta

# What's left to do for version 1:
# - implement listing of saved positions (on load commands without params)
# - fix discovering things conditions (look at rubble) and make custom actions more general
# - implement talk_to_x and ask_x_about_y commands 
# - implement general parser for command line (put command list and associations to separate file?)

# Stuff to do in future versions:
# - make game to behave more like a console (command history, auto-completion)
# - make objects in game context-sensitive 
# (1: rusty sword == sword if there are not other swords around
# 2: if there are both rusty and shining sword, let user pick one)

require 'yaml'

# prints array in following format: x, y and z
class Array
  def to_sentence(pars = {})
    pars = { :operator => ' and ', :prepend => '', :append => '.', :on_empty => 'nothing' }.merge(pars)
  
    sentence = case self.size 
      when 0 then pars[:on_empty]
      when 1 then self.first
      when 2 then self.join(pars[:operator])
      else (self.slice(0, (self.size - 2)) + [ "#{self[-2]}#{pars[:operator]}#{self[-1]}" ]).join(', ')
    end
    
    "#{pars[:prepend]}#{sentence}#{pars[:append]}"
  end
end

# PS: only this method or Player.say will be kept - this is gotta be refactored
def say(message, options = {})
  puts (message.is_a?(Symbol) ? Message.find_by_alias(message) : message) unless options[:load_mode]
end

# this class is prety minimalistic right now, but it can grow bigger
class Message
  MESSAGES = YAML.load(File.read('messages.yml'))

  def self.find_by_alias(message_alias)
    MESSAGES[message_alias.to_s]
  end
end

# basic class for game objects
class Thing
  attr_accessor :alias, :name, :description, :location, :visible, :pickable

  def initialize(hsh = {})
    allowed_attr_names.each do |attr_name|
      self.send("#{attr_name}=", hsh[attr_name]) if hsh.has_key?(attr_name)
    end
  end

  def name
    self.alias.gsub(/_/, ' ')
  end

  def in_location?(location_alias)
    self.location == location_alias
  end

  private
  
  def allowed_attr_names
    %w{ alias description location visible pickable }  
  end
end

# - can contain Things
# - has directions
class Location < Thing
  attr_accessor :name, :contains, :directions

  DIRECTION_SHORTCUTS = { 's' => 'south', 'n' => 'north', 'e' => 'east', 'w' => 'west' }

  # prints formatted list of directions for certain location
  def formatted_directions
    directions.keys.collect{ |k| DIRECTION_SHORTCUTS[k] }.to_sentence(:prepend => 'You can go ', :on_empty => 'nowhere')
  end

  private
    
  def allowed_attr_names
    %w{ alias name description contains directions }  
  end
end

# Game contains various data about game world and its rules, also handles various game states
class Game
  attr_accessor :locations, :things, :custom_actions, :console_log
  
  CONSOLE_LOG_PATH = Dir::pwd + '/console_log.txt'
  SAVED_GAMES_DIR = Dir::pwd + '/saved_games/'

  def initialize()
    self.load_locations()
    self.load_things()
    self.load_custom_actions()
    # persons
    @console_log = File.open(CONSOLE_LOG_PATH,'w')

    Dir::mkdir(SAVED_GAMES_DIR) unless File.exists?(SAVED_GAMES_DIR)
  end
    
  def load_locations()
    self.locations = {}
    yaml_locations = YAML::load_file('locations.yml')
    yaml_locations.keys.each { |key| self.locations[key] = Location.new(yaml_locations[key]) }
  end
  
  def load_things()
    self.things = {}
    yaml_things = YAML::load_file('things.yml')
    yaml_things.keys.each { |key| self.things[key] = Thing.new(yaml_things[key]) }
  end

  # perhaps I could add a Constrain object in the future, but let's keep it like this for now
  def load_custom_actions()
    self.custom_actions = YAML::load_file('custom_actions.yml')
  end

  def log_command(command)
    self.console_log.puts(command) unless ['','exit','quit'].include?(command)
  end

end

# Player class represents user who interacts with the Game
# ideally should be mostly Player.do_action(action_parameters_hash))
class Player
  attr_accessor :game, :location, :current_location, :previous_location, :constraints, :error_msg

  # PS: only this method or Player.say will be kept - this is gotta be refactored
  def say(message)
    puts (message.is_a?(Symbol) ? Message.find_by_alias(message) : message) unless @switches[:load_mode] 
  end

  def initialize()
    start()
  end

  # start new game
  def start()
    @game = Game.new

    @current_location = 'plain'
    @previous_location = nil

    @constraints = { :chapel_unlocked => false }
    @error_msg = nil
    @switches = {}
  end

  # returns current location object
  def location
    @game.locations[@current_location]
  end

  # returns inventory content in array
  def inventory
    @game.things.values.collect { |t| (t.location == 'i') ? t.alias : nil }.compact
  end
  
  # prints list of visible things in current location or content of inventory
  def things_in_location(location_alias = @current_location)
    things_in_location_bare(location_alias).to_sentence( :prepend => ((location_alias == 'i') ? 'You carry ' : 'There is ') )    
  end

  def things_in_location_bare(location_alias = @current_location)
    @game.things.values.collect { |t| (t.in_location?(location_alias) and t.visible) ? t.name : nil }.compact
  end

  # if your location has changed, look around
  def look_around()
    if (@current_location != @previous_location)
      say "#{self.location.name}\n\n#{self.location.description}\n\n" +
        "#{self.location.formatted_directions}\n#{self.things_in_location}\n"
      @previous_location = @current_location
    end
  end

  # does such thing exist thing present in hash of visible things that are either in current location or in inventory?
  def can_look_at?(thing_alias)
    @game.things.has_key?(thing_alias) &&
    ((@game.things[thing_alias].location == @current_location) || (@game.things[thing_alias].location == 'i')) && 
    (@game.things[thing_alias].visible == true)
  end

  def look_at(thing_name)
    thing_alias = thing_name.gsub(/ +/, '_')
  
    say (can_look_at?(thing_alias) ? "It's #{@game.things[thing_alias].description}." : "You can't see any #{thing_name} here.")
  end
    
  def can_pick_up?(thing_alias)
    # does such thing exist in the game? is it visible, pickable and in current location?
    @game.things.has_key?(thing_alias) && 
    @game.things[thing_alias].visible &&
    @game.things[thing_alias].pickable && 
    (@game.things[thing_alias].location == @current_location)
  end

  def pick_up(thing_name)
    thing_alias = thing_name.gsub(/ +/, '_')

    if can_pick_up?(thing_alias)
      # pick up = set thing's location as inventory 
      @game.things[thing_alias].location = 'i'
      say "You picked up #{thing_name}."
    # if it's already in you inventory
    elsif self.inventory.include?(thing_alias)
      say "You already carry #{thing_name}."
    else
      say "You can't pick up #{thing_name}."
    end
  end

  # used only in drop method, but outsorced because of clarity
  def can_drop?(thing_alias)
    unless @game.things.has_key?(thing_alias)
      false 
    else
      inventory.include?(thing_alias)
    end
  end
  
  # drop object in current location
  def drop(thing_name)
    thing_alias = thing_name.gsub(/ +/, '_')

    if self.can_drop?(thing_alias)
      @game.things[thing_alias].location = @current_location  
      say "You dropped #{thing_name}."
    else
      say "You don't carry #{thing_name}."
    end
  end

  # this might be moved to perform action
  def can_walk_to?(direction)
    location.directions.has_key?(direction)
  end

  def walk_to(direction)
    if can_walk_to?(direction)
      @current_location = location.directions[direction]
    else   
      say 'You can\'t go that way.'
    end
  end

  def display_inventory()
    say (inventory.empty? ? "You don't have anything." : things_in_location('i'))
  end

  def save_game(file_name = nil)

    unless file_name
      game_nr = 1
      game_nr += 1 while File.exists?("#{Game::SAVED_GAMES_DIR}save#{sprintf("%03d",game_nr)}.sav")
      file_name = game_nr.to_s # we we can compare it to regular expression
    end 

    # format numbers-only file_names
    file_name = "save#{sprintf("%03d",file_name)}" if (file_name =~ /^\d+$/)

    @game.console_log.close
  
    saved_game = File.new("#{Game::SAVED_GAMES_DIR}#{file_name}.sav", "w")
    saved_game.puts File.read(Game::CONSOLE_LOG_PATH)
    saved_game.close
 
    @game.console_log = File.open(Game::CONSOLE_LOG_PATH,'a') # re-open console log

    say "Game was saved as #{file_name}.sav"  
  end  

  def load_game(file_name = nil)
    # if load game is called withotu parameter, print saved games alphabetically
    unless file_name
      Dir.new(Game::SAVED_GAMES_DIR).each do |file| 
        puts "[#{file.gsub(/\.sav$/, '')}]" if (file =~ /\.sav$/)
      end
      return nil
    end

    file_name = "#{file_name}.sav"
      
    unless File.exists?("#{Game::SAVED_GAMES_DIR}#{file_name}")
      say "This saved game doesn't exist."
    else
      self.start

      @switches[:load_mode] = true

      File.read("#{Game::SAVED_GAMES_DIR}#{file_name}").split("\n").each do |line|
        self.process_line(line)
      end

      @switches.delete(:load_mode)

      # update console log (this is ugly, gotta refactor)
      self.game.console_log.close
      self.game.console_log = File.open(Game::CONSOLE_LOG_PATH,'w')
      self.game.console_log.puts(File.read("#{Game::SAVED_GAMES_DIR}#{file_name}"))
  
      say "Loaded save game: #{file_name}"
    end
  end

  def perform_action(pars = {})
    prepositions = { 'use' => 'on', 'give' => 'to', 'examine' => nil }

    pars[:alias] = [ pars[:command], pars[:object1], prepositions[pars[:command]], pars[:object2] ].compact.join('_')
    custom_action = self.game.custom_actions[pars[:alias]]

    # check if custom action is not defined
    unless custom_action
      return false
    else
      # firstly check general actions for given command
      # for use: do you carry object1? is object2 in current location? (find out it's location first)
      if %w{use give}.include?(pars[:command]) and (self.game.things[pars[:object1]].location != 'i')
        say "You don't carry #{pars[:object1_name]}."
      # also check if it's a valid thing
      elsif %w{use give}.include?(pars[:command]) and not things_in_location_bare.include?(pars[:object2])
        say "There's no #{pars[:object2_name]} nearby."
      elsif %w{examine}.include?(pars[:command]) and not things_in_location_bare.include?(pars[:object1])
        say "There's no #{pars[:object1_name]} nearby."
      else
        # implement conditions - after we pick up gemstone we can still see it in a rubble 
        # (revert to old discover_things mode)
        # conditions = []
        # while (custom_action.last =~ /^\?/) { conditions << custom_action.pop }
        # puts conditions

        custom_action.each { |a| perform_custom_action(a, pars) }
      end

      return true
    end
  end

  def perform_custom_action(action_alias, pars)
    cmd, obj = action_alias.split(' ') 

    # PS: might use case instead of if, but we might need to use regular expressions
    # this might be refactored in future as 'say' function is IMHO not really necessary
    if (cmd == 'say')
      say (obj ? obj : pars[:alias]).to_sym 
    elsif (cmd == 'remove')
      self.game.things[obj].location = nil
    elsif (cmd == 'add')
      self.game.things[obj].location = 'i'
    elsif (cmd == 'visible')
      self.game.things[obj].visible = true
    end
  end

# this is original locations handling - stored here for future reference
# PS: locations constraints are probably going to be moved to Location class
#  def can_walk_to?(direction)
#      return check_location_constraints(:from => @current_location, :to => location.directions[direction])
#    else
#      raise 'Unknown action type.'
#    end
#  end
#  
#  def check_location_constraints(params = {})
#    if params[:to] == 'chapel_interior'
#      unless @constraints[:chapel_unlocked]
#        @error_msg = "You can't go in, the chapel is locked."
#        return false
#      end
#    end
#    return true
#  end

  # process line and do given command if it makes sense
  def process_line(line = '', pars = {})
    # log this action
    @game.log_command(line) unless (line =~ /^(save|load)/)

    # 1st tier - single-word commands
  
    # process direction - go north/south/east/west
    if %w{ n s e w north south east west }.include?(line)
      walk_to(line.slice(0..0)) # take only the first character

    # display content of inventory
    elsif %w{ i inv inventory }.include?(line)
      display_inventory()
  
    # re-display description of the location (the look-around)
    elsif %w{ l look info }.include?(line)
      self.previous_location = nil
  
    # 2nd tier
    
    # examine object - display its description
    # refactor to Thing.lookable? can_pick_up? dropable?
    elsif (line =~ /^(l|look|look at|e|examine) (.+)$/)
      thing_name = $2
      thing_alias = thing_name.gsub(/ +/, '_')

      self.look_at(thing_name) unless self.perform_action(:command => 'examine', :object1 => thing_alias, :object1_name => thing_name)
      
    elsif (line =~ /^(t|take|p|pick up) (.+)$/)
      self.pick_up($2)
      
    elsif (line =~ /^(d|drop) (.+)$/)
      self.drop($2)
  
    elsif (line == 'save') || (line =~ /^save (.+)$/)
      self.save_game($1)

    elsif %w{load restore}.include?(line) || (line =~ /^(load|restore) (.+)$/)
      self.load_game($2)
      
    # 3rd tier
    
    # give thing (to) person
    elsif (line =~ /^(g|give) (.+)$/)
      # to be outsourced to separate parser
      command_data = $2
      thing_name, give_to_name = command_data.split(' to ')
      thing_name, give_to_name = command_data.split(' ', 2) unless give_to_name
      thing_alias = thing_name.gsub(/ +/, '_')
      give_to = give_to_name.gsub(/ +/, '_')

      # this should be refactored
      puts "You cannot give that." unless self.perform_action(:command => 'give', :object1 => thing_alias, :object2 => give_to, 
        :object1_name => thing_name, :object2_name => give_to_name)      

    # use thing on thing
    elsif (line =~ /^(u|use) (.+)$/)
      # to be outsourced to separate parser
      command_data = $2
      thing_name, use_on_name = command_data.split(' on ')
      thing_name, use_to_name = command_data.split(' ', 2) unless use_on_name
      thing_alias = thing_name.gsub(/ +/, '_')
      use_on = use_on_name.gsub(/ +/, '_')
      
      puts "You cannot use that." unless self.perform_action(:command => 'use', :object1 => thing_alias, :object2 => use_on, 
        :object1_name => thing_name, :object2_name => use_on_name) 
  
    else
      puts 'Unknown command.' unless (line.nil? || line.empty? || line =~ /^(quit|exit)$/)
    end
  end

end

# main loop

game_player = Player.new

line = ''

while (line !~ /^(quit|exit)$/) do
  game_player.look_around()

  print '> '
  line = readline
  line.chomp!

  game_player.process_line(line)
end

# delete command log
File.delete(Game::CONSOLE_LOG_PATH) if File.exists?(Game::CONSOLE_LOG_PATH)

game_player.say('See ya!')
