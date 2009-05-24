
# The story originates from Fallout 3 minigame - Reign of Grelok beta

# - replace puts with internal display method (and fix displaying messages during loading game)
# - make object in game context-sensitive 
# (1: rusty sword == sword if there are not other swords around
# 2: if there are both rusty and shining sword, let user pick one)
# - interprocess communication - make GameState and Thing subclasses of Game
# - generalize conditions

# PS: there should be a table of constraints and state handling (we should be able to save state)

require 'yaml'

class Message
  MESSAGES = YAML.load(File.read('messages.yml'))

  def self.display(message_alias)
    puts MESSAGES[message_alias]
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
  # example: You can go north, south and west.
  def formatted_directions
    dirs = directions.keys.collect{ |k| DIRECTION_SHORTCUTS[k] }

    last_dir = ((dirs.size > 1) ? " and #{dirs.last}" : "")

    "You can go #{dirs.join(', ') + last_dir}."
  end

  private
    
  def allowed_attr_names
    %w{ alias name description contains directions }  
  end
end

# wrapper class for everything related to grelok game
class Game
  attr_accessor :locations, :things, :console_log
  
  CONSOLE_LOG_PATH = Dir::pwd + '/console_log.txt'
  SAVED_GAMES_DIR = Dir::pwd + '/saved_games/'

  def initialize()
    @locations = load_locations()
    @things = load_things()
    # constraints
    # persons
    @console_log = File.open(CONSOLE_LOG_PATH,'w')

    Dir::mkdir(SAVED_GAMES_DIR) unless File.exists?(SAVED_GAMES_DIR)
  end

  def self.start()
    GameState.new
  end
    
  # PS: should be moved to Location class 
  # PS: directions could be stored in special file and then mapped to locations during load
  def load_locations()
    locations = {}
    yaml_locations = YAML::load_file('locations.yml')
    yaml_locations.keys.each { |key| locations[key] = Location.new(yaml_locations[key]) }
    return locations
  end
  
  def load_things()
    things = {}
    yaml_things = YAML::load_file('things.yml')
    yaml_things.keys.each { |key| things[key] = Thing.new(yaml_things[key]) }
    return things
  end

end

# stores information about the state in the game: where you are, things you carry, roadblocks you've overcame...
class GameState
  attr_accessor :game, :location, :current_location, :previous_location, :action_type, :constraints, :error_msg

  # start new game
  def initialize()
    @game = Game.new
      
    @current_location = 'plain'
    @previous_location = nil
    
    @action_type = nil
    
    @constraints = { :chapel_unlocked => false }
    @error_msg = nil
  end

  # ugly, gotta refactor
  def restart
    @game = Game.new
      
    @current_location = 'plain'
    @previous_location = nil
    
    @action_type = nil
    
    @constraints = { :chapel_unlocked => false }
    @error_msg = nil
  end

  def log_command(command)
    @game.console_log.puts(command) unless ['','exit','quit'].include?(command)
  end

  def location
    @game.locations[@current_location]
  end

  # to do: enable inventory << thing
  
  # prints the content of inventory
  def inventory
    inv = []
    @game.things.keys.each do |key| 
      inv << @game.things[key].alias if (@game.things[key].location == 'i')
    end
    return inv
  end
  
  # print list of visible things in current location or content of inventory
  def things_in_location(location_alias = @current_location)
    thing_names = []
    
    @game.things.keys.each do |key| 
      if (@game.things[key].location == location_alias) and @game.things[key].visible 
        thing_names << @game.things[key].name
      end
    end

    # to do: there is x, y and z.
    if (thing_names.size > 1)
      last_thing = thing_names.pop
      thing_names[-1] = "#{thing_names[-1]} and #{last_thing}"
    end
    
    "\n#{(location_alias == 'i') ? 'You carry' : 'There is'} #{thing_names.join(', ')}." if (thing_names.size > 0)
  end

  # hash of things that are either in current location or in inventory
  def active_things(location_alias = @current_location)
    # cache it later according to location
    @active_things = {}
  
    @game.things.keys.each do |key| 
        if (@game.things[key].location == location_alias) || (@game.things[key].location == 'i')
          @active_things[key] = @game.things[key]
        end
      end
    
    return @active_things
  end  
  
  def print_info
    print "#{location.name}\n\n#{location.description}\n\n#{location.formatted_directions}\n#{things_in_location}\n\n"
  end
  
  def pickable?(thing_alias)
    # check if thing even exists
    unless @game.things.has_key?(thing_alias)
      false 
    else
      @game.things[thing_alias].pickable && (@game.things[thing_alias].location == @current_location)
    end    
  end

  def pick_up(thing_alias)
    @game.things[thing_alias].location = 'i' if pickable?(thing_alias)
  end
  
  def droppable?(thing_alias)
    # check if thing even exists
    unless @game.things.has_key?(thing_alias)
      false 
    else
      inventory.include?(thing_alias)
    end
  end

  def drop(thing_alias)
    @game.things[thing_alias].location = @current_location if droppable?(thing_alias)    
  end

  def allowed_by_constraints?(params = {})
    if @action_type == :walk
      return check_location_constraints(:from => @current_location, :to => location.directions[params[:direction]])
    else
      raise 'Unknown action type.'
    end
  end
  
  def check_location_constraints(params = {})
    if params[:to] == 'chapel_interior'
      unless @constraints[:chapel_unlocked]
        @error_msg = "You can't go in, the chapel is locked."
        return false
      end
    end

    return true
  end

  # process line and do given command if it makes sense
  def process_line(line = '', pars = {})
    # log this action
    self.log_command(line) unless (line =~ /^(save|load)/)
  
    # 1st tier - single-word commands
  
    # process direction - go north/south/east/west
    if %w{ n s e w north south east west }.include?(line)
      self.action_type = :walk
      direction = line.slice(0..0)
  
      if self.location.directions.has_key?(direction)
        if self.allowed_by_constraints?(:direction => direction)
          self.current_location = self.location.directions[direction]
        else
          puts self.error_msg
        end
      else
        puts 'You can\'t go that way.'
      end
    # display content of inventory
    elsif %w{i inv inventory }.include?(line)
      if self.inventory.empty?
        puts "You don't have anything."
      else
        puts self.things_in_location('i')
      end
  
    # re-display description of the location (the look-around)
    elsif %w{ l look info }.include?(line)
      self.previous_location = nil
  
    # 2nd tier
    
    # examine object - display its description
    # refactor to Thing.lookable? pickable? dropable?
    elsif (line =~ /^(l|look at|e|examine) (.+)$/)
      self.action_type = :look
      thing_name = $2
      thing_alias = thing_name.gsub(/ +/, '_')
  
      # general constraint: thing has to be in current_location or inventory
      if self.active_things.keys.include?(thing_alias)
        puts "It's #{self.active_things[thing_alias].description}."
      else
        puts "You can't see any #{thing_name} here."
      end
  
      # check constraints
      if (self.current_location == 'mountain') and (thing_alias == 'rubble')
        self.game.things['gemstone'].visible = true
        puts 'You notice a beautiful gemstone lying in the rubble.'
      end
      
    # take object in certain location
    elsif (line =~ /^(t|take|p|pick up) (.+)$/)
      self.action_type = :pick_up
      thing_name = $2
      thing_alias = thing_name.gsub(/ +/, '_')
      
      if self.pickable?(thing_alias) and self.game.things[thing_alias].visible
        self.pick_up(thing_alias)
        puts "You picked up #{thing_name}."
      # if it's already in you inventory
      elsif self.inventory.include?(thing_alias)
        puts "You already carry #{thing_name}."
      else
        puts "You can't pick up #{thing_name}."
      end
      
    # drop object in certain location
    elsif (line =~ /^(d|drop) (.+)$/)
      self.action_type = :drop
      thing_name = $2
      thing_alias = thing_name.gsub(/ +/, '_')
  
      if self.droppable?(thing_alias)      
        puts "You dropped #{thing_name}." if self.drop(thing_alias)
      else
        puts "You don't carry #{thing_name}."
      end
  
    # save game
    elsif (line == 'save')
      self.game.console_log.close
      saved_game_nr = 1
      saved_game_nr += 1 while File.exists?("#{Game::SAVED_GAMES_DIR}save#{sprintf("%03d",saved_game_nr)}.sav")
  
      saved_game = File.new("#{Game::SAVED_GAMES_DIR}save#{sprintf("%03d",saved_game_nr)}.sav", "w")
      saved_game.puts File.read(Game::CONSOLE_LOG_PATH)
      saved_game.close
  
      self.game.console_log = File.open(Game::CONSOLE_LOG_PATH,'a') # re-open console log
      puts "Game was saved as save#{sprintf("%03d",saved_game_nr)}.sav"  
  
    # load game - this is not implemented yet
    elsif (line =~ /^(load|restore) (.+)$/)
      saved_game_file = $2
      if (saved_game_file =~ /^\d+$/)
        saved_game_file = "save#{sprintf("%03d",saved_game_file)}.sav"
      elsif (saved_game_file =~ /\.sav$/i)
        "#{saved_game_file}.sav" 
      end
  
      unless File.exists?("#{Game::SAVED_GAMES_DIR}#{saved_game_file}")
        puts "This saved game doesn't exist."
      else
        # self = Game.start()
        self.restart

        File.read("#{Game::SAVED_GAMES_DIR}#{saved_game_file}").split("\n").each do |line|
          self.process_line(line, :load_mode => true)
        end

        # update console log (this is ugly, gotta refactor)
        self.game.console_log.close
        self.game.console_log = File.open(Game::CONSOLE_LOG_PATH,'w')
        self.game.console_log.puts(File.read("#{Game::SAVED_GAMES_DIR}#{saved_game_file}"))
  
        self.log_command('Wohoo!!!') 

        puts "Loaded save game: #{saved_game_file}"
      end
  
    # 3rd tier
    
    # give thing to person
    elsif (line =~ /^(g|give) (.+)$/)
      thing_name, give_to_name = $2.split(' to ')
      thing_alias = thing_name.gsub(/ +/, '_')
      give_to = give_to_name.gsub(/ +/, '_')
  
      # to do: in general if you have the thing (or is in current_location) and give_to is in current location
      if (thing_alias == 'gemstone') and (give_to == 'wizard') 
        # do you have that thing?
        if (self.game.things[thing_alias].location != 'i')
          puts "You don't carry #{thing_name}."
        # are you in correct location
        elsif (self.current_location != 'swamp')
          puts "There's no #{give_to_name} nearby."
        # ok, give the item away
        else 
          self.game.things[thing_alias].location = nil
          self.game.things['gemstone_shards'].visible = true
          Message.display('give_gemstone_to_wizard')
        end
  
      # try to give gemstone to smith
      # to do: in general if you have the thing (or is in current_location) and give_to is in current location
      elsif (thing_alias == 'gemstone') and (give_to == 'blacksmith') 
        # do you have that thing?
        if (self.game.things[thing_alias].location != 'i')
          puts "You don't carry #{thing_name}."
        # are you in correct location
        elsif (self.current_location != 'town')
          puts "There's no #{give_to_name} nearby."
        # ok, give the item away
        else 
          Message.display('give_gemstone_to_blacksmith')
        end
  
      # to do: in general if you have the thing (or is in current_location) and give_to is in current location
      elsif (thing_alias == 'gemstone_shards') and (give_to == 'blacksmith') 
        # do you have that thing?
        if (self.game.things[thing_alias].location != 'i')
          puts "You don't carry #{thing_name}."
        # are you in correct location
        elsif (self.current_location != 'town')
          puts "There's no #{give_to_name} nearby."
        # ok, give the item away
        else 
          # PS: to do: instead of visible switch, why don't you set thing.location to nil? that's the same, isn't it?
          # on the other hand, thing location should be kept (shining_sword should be in inventory, but invisible)
          self.game.things[thing_alias].location = nil
          self.game.things['rusty_sword'].location = nil
          self.game.things['shining_sword'].location = 'i'
          Message.display('give_gemstone_shards_to_blacksmith')
        end
  
      else
        puts "Nothing happens."
      end
    
    # use thing on thing
    elsif (line =~ /^(u|use) (.+)$/)
      thing_name, use_on_name = $2.split(' on ')
      thing_alias = thing_name.gsub(/ +/, '_')
      use_on = use_on_name.gsub(/ +/, '_')
          
      # to do: check both object plus automatic check on use_on location
      if (thing_alias == 'rusty_sword') and (use_on == 'grelok')
        if (self.game.things[thing_alias].location != 'i')
          puts "You don't carry #{thing_name}."
        # also check if it's a valid thing
        elsif (self.current_location != 'mountain')
          puts "There's no #{use_on_alias} nearby."
        else
          Message.display('use_rusty_sword_on_grelok')
        end
  
      elsif (thing_alias == 'shining_sword') and (use_on == 'grelok')
        if (self.game.things[thing_alias].location != 'i')
          puts "You don't carry #{thing_name}."
        # also check if it's a valid thing
        elsif (self.current_location != self.game.things[use_on].location)
          puts "There's no #{use_on_alias} nearby."
        else
          Message.display('use_shining_sword_on_grelok')
          exit
        end
      
      else
        puts "Nothing happens."
      end
  
    else
      puts 'Unknown command.' unless (line.nil? || line.empty? || line =~ /^(quit|exit)$/)
    end
  end

end

# game main loop

gs = Game.start()

line = ''

while (line !~ /^(quit|exit)$/) do
  # if you changed location, print look-around
  if (gs.current_location != gs.previous_location)
    gs.print_info 
    gs.previous_location = gs.current_location
  end

  print '> '
  line = readline
  line.chomp!

  gs.process_line(line)
end

# delete command log
File.delete(Game::CONSOLE_LOG_PATH) if File.exists?(Game::CONSOLE_LOG_PATH)

puts 'See ya!'
