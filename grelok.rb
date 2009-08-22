
# The story originates from Fallout 3 minigame - Reign of Grelok beta

# What's left:
# - handle and check line_pars depending on command
# - make current contect more robust, return sensible answers to blind-alley commands
# (for example: give gemstone to priest - don't return default response)
# - implement talk_to_x, ask_x_about_y commands (for current content first - blacksmith, wizard and Grelok)
# - add graveyard and chapel locations, zombie and grave, and basin with holy water 
# and ability to fill water flask with water, also subquest with priest
# - how about attributes of objects? flask can be full, empty, there can be several same objects like coins

require 'yaml'
require 'readline'

# don't exit when you get an interrupt signal (Crtl+C)
trap('INT', 'SIG_IGN')

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

  public

  def self.alias_to_name(thing_alias)
   thing_alias.tr('_', ' ')
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

  DIRECTIONS = %w{ n s e w north south east west }

  COMMANDS = YAML.load(File.read(Dir::pwd + '/commands.yml'))

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
    yaml_things.keys.each do |key| 
      self.things[key] = Thing.new(yaml_things[key])
      # most things are visible, so setting this as default value instead of 
      # configuring it in things.yml file. we might take this attribute out
      # in future, because it's kinda redundant when we can also set object's
      # location to nil. but we still use it for hidden objects in locations
      # PS: can't use ||=, this conditions acts kinda weird here
      self.things[key].visible = true if self.things[key].visible.nil?
    end
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
  attr_accessor :game, :location, :current_location, :previous_location, :active_objects, :active_objects_shortcuts, :constraints, :error_msg

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
    @active_objects = []
    @active_objects_shortcuts = []

    @constraints = YAML::load_file('constraints.yml')
    @error_msg = nil
    @switches = {}
  end

  # returns current location object
  # PS: this is duplicate with class.location attribute, check and eventually remove the attribute
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

  def autocompletion_array
    @active_objects + @active_objects_shortcuts
  end

  # if your location has changed, look around
  def look_around()
    if (@current_location != @previous_location)
      say "#{self.location.name}\n\n#{self.location.description}\n\n" +
        "#{self.location.formatted_directions}\n#{self.things_in_location}\n"
      @previous_location = @current_location
    end

    # create a list of active objects: inventory + objects in current location
    @active_objects = self.inventory.collect { |t| Thing.alias_to_name(t) } + self.things_in_location_bare(self.current_location)
    # get shortened names of objects (should be saved as thing's short name attribute)
    @active_objects_shortcuts = @active_objects.collect do |t| 
      words = t.split(' ')
      (words.size > 1) ? words.last : nil
    end.compact
  end

  # does such thing exist thing present in hash of visible things that are either in current location or in inventory?
  def can_look_at?(thing_alias)
    @game.things.has_key?(thing_alias) &&
    ((@game.things[thing_alias].location == @current_location) || (@game.things[thing_alias].location == 'i')) && 
    (@game.things[thing_alias].visible == true)
  end

  def look_at(thing_alias)
    # if there's no thing name, only look around
    if thing_alias.nil? || thing_alias.empty?
      self.previous_location = nil # to trigger look_around_method
    else
      thing_name = Thing.alias_to_name(thing_alias)
      say(can_look_at?(thing_alias) ? "It's #{@game.things[thing_alias].description}." : "You can't see any #{thing_name} here.")
    end
  end
    
  def can_pick_up?(thing_alias)
    # does such thing exist in the game? is it visible, pickable and in current location?
    @game.things.has_key?(thing_alias) && 
    @game.things[thing_alias].visible &&
    @game.things[thing_alias].pickable && 
    (@game.things[thing_alias].location == @current_location)
  end

  def pick_up(thing_alias)
    thing_name = Thing.alias_to_name(thing_alias)

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
  def drop(thing_alias)
    thing_name = Thing.alias_to_name(thing_alias)

    if self.can_drop?(thing_alias)
      @game.things[thing_alias].location = @current_location  
      say "You dropped #{thing_name}."
    else
      say "You don't carry #{thing_name}."
    end
  end

  def can_go?(direction)
    location.directions.has_key?(direction) and not @constraints['locations']["#{@current_location}-#{direction}"]
  end

  def go(direction)
    # take just the first character from direction
    direction = (direction.is_a?(Array) ? direction[0] : direction).slice(0,1)

    if can_go?(direction)
      @current_location = location.directions[direction]
    else
      say(@constraints['locations']["#{@current_location}-#{direction}"] || 'You can\'t go that way.')
    end
  end

  def display_inventory(dummy_parameter = nil)
    say (inventory.empty? ? "You don't have anything." : things_in_location('i'))
  end

  def quit_game(dummy_parameter = nil)
    say('See ya!')
  end

  def save_game(file_name = nil)

    if file_name.to_s.empty?
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
    # if load game is called without parameters, offer games to load
    if file_name.to_s.empty?
      saved_games = []
      Dir.new(Game::SAVED_GAMES_DIR).each do |file| 
        saved_games << "[#{file.gsub(/\.sav$/, '')}]" if (file =~ /\.sav$/)
      end

      if saved_games.empty?
        puts "No saved games are available."
      else
        puts "Which game do you want to load?\n" + saved_games.join("\n")
      end

      return nil
    end

    file_name = "#{file_name}.sav" unless (file_name =~ /\.sav/)
      
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

  # perform special stuff if command hits custom actions
  def perform_custom_action(command_alias, command, line_pars = [])
    custom_action = self.game.custom_actions[command_alias]
    # no standard action found (let's go to default actions)
    return false unless custom_action

    line_pars = [ line_pars ] unless line_pars.is_a?(Array)

    # extract parameters from input line
    pars = { :command_alias => command_alias, :command => command }
    pars[:par1], pars[:par2] = line_pars
    pars[:par1_name], pars[:par2_name] = line_pars.collect { |p| p.gsub(/_/, ' ') }

    # check general conditions specific for this action

    # for use: do you carry object1? is object2 in current location? (find out it's location first)
    if %w{use give}.include?(pars[:command]) and (self.game.things[pars[:par1]].location != 'i')
      say "You don't carry #{pars[:par1_name]}."
    # also check if it's a valid thing
    elsif %w{use give}.include?(pars[:command]) and not things_in_location_bare.include?(pars[:par2])
      say "There's no #{pars[:par2_name]} nearby."
    elsif %w{look_at}.include?(pars[:command]) and not things_in_location_bare.include?(pars[:par1])
      say "There's no #{pars[:par1_name]} nearby."

    # if general conditions are ok, go to custom conditions and actions
    else
      custom_action.each { |a| break unless perform_custom_action_internal(a, pars) }
    end

    return true
  end

  def perform_custom_action_internal(action_alias, pars)
    cmd, obj = action_alias.split(' ', 2) 

    # if there are action-specifi conditions and some of them ends false, don't perform actions
    return verify_specific_condition(obj) if (cmd == 'verify')

    # PS: might use case instead of if, but we might need to use regular expressions
    # this might be refactored in future as 'say' function is IMHO not really necessary
    if (cmd == 'say')
      say (obj ? obj : pars[:command_alias]).to_sym 
    elsif (cmd == 'remove')
      self.game.things[obj].location = nil
    elsif (cmd == 'add')
      self.game.things[obj].location = 'i'
    elsif (cmd == 'visible')
      self.game.things[obj].visible = true
    elsif (cmd == 'exit')
      exit
    end

    return true
  end

  def verify_specific_condition(data)
    data = data.split(' ')
    condition_type = data.shift

    # is certain thing in certain location?
    if (condition_type == 'location')
      return (@game.things[data[0]].location == data[1])
    else
      raise 'unknown condition type'
    end
  end

  # divide line into command and parameters and call command-related function
  def process_line(line)
    # if you don't get any text, do nothing
    return false if line.empty?

    # add command into log, so we can create a savegame from it later
    # PS: we could also use console history for that
    @game.log_command(line) unless (line =~ /^(save|load)/)

    line_pars = line.split(/\s+/)

    # identify command 
    command = nil
    Game::COMMANDS.each_pair do |k,a| 
      if a.include?(line_pars[0])
        command = k
        break
      end
    end
    command = line_pars[0] unless command
    line_pars.shift

    # throw away prepositions we don't use for parsing: look (at), pick (up), talk (to)...
    # PS: this mean prepositions after verb, not items separators which are handled later
    line_pars.shift if %w{ at up to with on }.include?(line_pars[0])  

    # get command alias, this is used to identify custom actions
    # command_alias = ( [ command ] + line_pars ).join('_')

    # get params for commands with 2 parameters
    if %{ give use attack ask }.include?(command)
      # rules: only one parameter or two separated by preposition
      %w{ to on with about }.each do |prep|
        if line_pars.include?(prep)
          line_pars = line_pars.join('_').split("_#{prep}_", 2)
          break
        end
      end
    # otherwise we suppose that we have only one (could be more-word) or zero params
    else
      line_pars = [ line_pars.join('_') ] unless line_pars.empty?
    end

    # hadle 'attack' command, which is basically just a synonym for 'use' command
    if (command == 'attack')
      command = 'use'
      line_pars.reverse!
      # command_alias = [ command, line_pars.join('_on_') ].join('_')
    end

    # handle directions - should be refactored, but it's low priority
    if (command =~ /^go_/)
      command, line_pars = command.split('_') 
      line_pars = [ line_pars ] 
    end

    # the array versus string parameters mess gotta be refactored
    line_pars = line_pars[0] if (line_pars.size == 1)
 
    # try to guess params based on their context
    # example: if you try to 'look at sword' and there's just rusty sword among active objects,
    # this command is automatically converted to 'look at rusty sword'
    updated_line_pars = []
    line_pars.each do |par|
      unless self.active_objects.include?(par)
        choosen_item = nil
        
        self.active_objects.each do |item|
          if (par == item.split(' ',2)[1])
            unless choosen_item
              choosen_item = item
            # in case we can't decide between more objects we don't do anything
            else
              puts "Which #{par} do you mean: #{choosen_item}, #{item} or something else?"
              choosen_item = nil
              return nil
            end
          end
        end

        par = choosen_item.gsub(' ', '_') if choosen_item
      end

      updated_line_pars << par
    end
    line_pars = ((updated_line_pars.size == 1) ? updated_line_pars[0] : updated_line_pars)

    # command_alias = [ command, line_pars.join('_on_') ].join('_')
    # get command alias, this is used to identify custom actions
    conjunction = case command 
      when 'use' then 'on'
      when 'give' then 'to'
      when 'ask' then 'about'
      else nil
    end
    # line_pars = [ line_pars ] unless (line_pars.class.name == 'Array')
    if conjunction
      command_alias = [ command, line_pars[0], conjunction, line_pars[1] ].join('_')      
    else
      command_alias = ([command] + [line_pars]).join('_')
    end

    # TO DO: handle and check line_pars depending on command (for example: look should have one param,
    # use should have array of two params, etc...)

    # display results of parsing
    # puts "command [#{command}]"; puts "line pars [#{line_pars.is_a?(Array) ? line_pars.join(" ") : line_pars}]"; puts "command alias: [#{command_alias}]"

    unless self.perform_custom_action(command_alias, command, line_pars) 
      if self.respond_to?(command)
        self.send(command, line_pars)
      else
        say 'Mighty Grognak is confused by this gibberish.'
      end
    end
  end

end

# main loop
game_player = Player.new
line = ''

until %w{ quit exit }.include?(line) do
  game_player.look_around()

  # create a list of active objects for autocompletion 
  # (inventory + visible objects in current location)
  comp = proc { |s| game_player.autocompletion_array.grep(/^#{s}/) }
  Readline.completion_append_character = " "
  Readline.completion_proc = comp

  # puts "active objects: " + game_player.autocompletion_array.collect { |t| "[#{t}]" }.join(", ").to_s

  line = Readline.readline('> ', true) # add_hist = true
  Readline::HISTORY.pop if line.empty?

  game_player.process_line(line)
end
