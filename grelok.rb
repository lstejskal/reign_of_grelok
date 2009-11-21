
# The story originates from Fallout 3 minigame - Reign of Grelok beta

# primary goal: create a single-file executable for windows
# GameData are duplicate right now, but let's get it to work first and worry about optimization later

# Updates for version 2:
# - refactor line_pars: 
#   - they should be always array
#   - "rusty_sword" vs. "rusty sword" - pick one form and stick with it
# - figure out how to use synonyms (use_gift_on_person == give_gift_to_person, etc)
# - make code centered around things, not around commands
# - why isn't location a thing as well? (or rather a child of thing)

require 'yaml'
require 'readline'

# system "ruby ./wrap_yaml_files.rb"
require 'game_data'

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

class String
  def chop_to_lines(max_width = 70)
    words = self.split(/ +/)
    arr = []

    str = ""
    words.each do |word|
      if (str.size >= max_width)
        arr << str
        str = ""
      end

      str += " #{word}"
    end

    arr << str unless str.empty?

    arr.collect { |line| line.lstrip }.join("\n")
  end
end

# this class is pretty minimalistic right now, but it can grow bigger
class Message
  @messages = GameData::MESSAGES # YAML.load(File.read('messages.yml'))

  def self.find_by_alias(message_alias)
    @messages[message_alias.to_s]
  end

  def self.replace(old_alias, new_alias)
    @messages[old_alias] = @messages[new_alias]
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
   thing_alias.to_s.tr('_', ' ')
  end

end
# 
# stores location data: alias, name, description and directions
# PS: does not contain things. thing's location is stored in thing_instance.location attribute
class Location < Thing
  attr_accessor :name, :directions

  DIRECTION_SHORTCUTS = { 's' => 'south', 'n' => 'north', 'e' => 'east', 'w' => 'west' }

  # prints formatted list of directions for certain location
  def formatted_directions
    directions.keys.collect{ |k| DIRECTION_SHORTCUTS[k] }.to_sentence(:prepend => 'You can go ', :on_empty => 'nowhere')
  end

  private
    
  def allowed_attr_names
    %w{ alias name description directions }  
  end
end

# Game contains various data about game world and its rules, also handles various game states
class Game
  attr_accessor :locations, :things, :custom_actions, :console_log
  
  CONSOLE_LOG_PATH = Dir::pwd + '/console_log.txt'
  SAVED_GAMES_DIR = Dir::pwd + '/saved_games/'

  DIRECTIONS = %w{ n s e w north south east west }

  COMMANDS = GameData::COMMANDS # YAML.load(File.read('commands.yml'))

  def initialize()
    self.load_locations()
    self.load_things()
    self.load_custom_actions()
    @console_log = File.open(CONSOLE_LOG_PATH,'w')

    Dir::mkdir(SAVED_GAMES_DIR) unless File.exists?(SAVED_GAMES_DIR)
  end
    
  def load_locations()
    self.locations = {}
    yaml_locations = GameData::LOCATIONS # YAML::load_file('locations.yml')
    yaml_locations.keys.each { |key| self.locations[key] = Location.new(yaml_locations[key]) }
  end
  
  def load_things()
    self.things = {}
    yaml_things = GameData::THINGS # YAML::load_file('things.yml')
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
    self.custom_actions = GameData::CUSTOM_ACTIONS # YAML::load_file('custom_actions.yml')
  end

  def log_command(command)
    self.console_log.puts(command) unless ['','exit','quit'].include?(command)
  end

end

# Player class represents user who interacts with the Game
# ideally should be mostly Player.do_action(action_parameters_hash))
class Player
  attr_accessor :game, :location, :current_location, :previous_location, :active_objects, :active_objects_shortcuts, :constraints, :error_msg

  # params:
  # load_mode - don't display anything if we're loading game
  # sym_only - display only messages that can be found by alias
  def say(message, options = {})
    options[:load_mode] = true if @switches[:load_mode]
    # put random 'error' message if we do not understand the command - keeping just one now for easier debugging
    message = "gibberish#{rand(1) + 1}".to_sym if (message == :what_a_gibberish)
    msg = (message.is_a?(Symbol) ? Message.find_by_alias(message) : (options[:sym_only] ? nil : message))
    puts msg.to_s.chop_to_lines if msg and not options[:load_mode]
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

    @constraints = GameData::CONSTRAINTS # YAML::load_file('constraints.yml')
    @error_msg = nil
    @switches = {
      :extended_prompt => true
    }
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

  def prompt
    @switches[:extended_prompt] ? "\n[#{self.location.name.downcase}: #{self.location.directions.keys.join(', ')}] > " : "\n> "
  end

  def is_active_object?(thing_alias)
    @active_objects.include?(Thing::alias_to_name(thing_alias))
  end

  # if your location has changed, look around
  def look_around()
    if (@current_location != @previous_location)
      puts ""
      say "#{self.location.name}\n\n"
      say "#{self.location.description}\n\n"
      say "#{self.location.formatted_directions}\n"
      say "#{self.things_in_location}\n"
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
    elsif not thing_name.empty?
      say "You can't pick up #{thing_name}."
    else
      say "Pick up what?"
    end
  end

  # drop object in current location
  def drop(thing_alias)
    thing_name = Thing.alias_to_name(thing_alias)

    if inventory.include?(thing_alias)
      @game.things[thing_alias].location = @current_location
      say "You dropped #{thing_name}."
    elsif not thing_name.empty?
      say "You don't carry #{thing_name}."
    else
      say "Drop what?"
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

  # command methods talk_to, ask, give, use and attack don't do anything except printing meaningfull errors
  # all of them are either custom actions and messages which - if they make sense - get run earlier

  def talk_to(pars = [])
    pars = [ pars ] unless pars.is_a?(Array)
    whom = pars.first

    if (pars.size > 1)
      say :what_a_gibberish
    elsif self.is_active_object?(whom)
      say "You can't chat with that." 
      # PS: assuming that all persons will have something to say, this applies to things
    else
      say "Talk to whom? I don't see any #{Thing.alias_to_name(whom)} around here."
    end
  end

  def ask(pars = [])
    pars = [ pars ] unless pars.is_a?(Array)
    whom = pars.first
    if self.is_active_object?(whom)
      say(Message::find_by_alias("ask_#{whom}_about_anything") || "You can't chat with that.")
    else
      say "Ask whom? I don't see any #{Thing.alias_to_name(whom)} around here."
    end
  end

  def give(pars = [])
    pars = [ pars ] unless pars.is_a?(Array)
    what = pars[0]
    whom = pars[1]

    if what.to_s.empty?
      say :what_a_gibberish
    elsif not inventory.include?(what)
      say "You don't have #{Thing.alias_to_name(what)}."
    elsif whom.to_s.empty?
      say "Give to whom?"
    elsif not self.is_active_object?(whom) 
      say "Give to whom? I don't see any #{Thing.alias_to_name(whom)} around here."
    else
      say(Message::find_by_alias("give_anything_to_#{whom}") || "That doesn't make sense.")
    end
  end

  # PS: this also handles attack command, which just use with switched parameters
  def use(pars = [])
    pars = [ pars ] unless pars.is_a?(Array)

    if pars[0].to_s.empty?
      say :what_a_gibberish
    elsif not inventory.include?(pars[0])
      say "You don't have #{Thing.alias_to_name(pars[0])}."
    # PS: we can use just one object, so we don't have to check if second object exists
    elsif !pars[1].to_s.empty? and !self.is_active_object?(pars[1]) 
      say "I don't see any #{Thing.alias_to_name(pars[1])} around here."
    else
      say "That doesn't make sense."
    end
  end

  def display_inventory(dummy_parameter = nil)
    say (inventory.empty? ? "You don't have anything." : things_in_location('i'))
  end

  alias :display :display_inventory

  def quit_game(dummy_parameter = nil)
    # crashes under Windows (insufficient rights?), so removing for now
    # File.delete(Game::CONSOLE_LOG_PATH) if File.exists?(Game::CONSOLE_LOG_PATH)
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
        say "No saved games are available."
      else
        say "Which game do you want to load?\n" + saved_games.join("\n")
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

    line_pars = [ line_pars ] unless line_pars.is_a?(Array)

    # extract parameters from input line
    pars = { :command_alias => command_alias, :command => command }
    pars[:par1], pars[:par2] = line_pars
    pars[:par1_name], pars[:par2_name] = line_pars.collect { |p| p.gsub(/_/, ' ') }

    # no standard action found (let's go to default actions)
    return false unless custom_action

    # check general conditions specific for this action

    # for use: do you carry object1? is object2 in current location? (find out it's location first)
    if %w{use give}.include?(pars[:command]) and (self.game.things[pars[:par1]].location != 'i')
      say "You don't carry #{pars[:par1_name]}."
    # also check if it's a valid thing
    elsif %w{use give}.include?(pars[:command]) and not things_in_location_bare.include?(pars[:par2_name])
      say "There's no #{pars[:par2_name]} nearby."
    elsif %w{look_at talk_to ask}.include?(pars[:command]) and not things_in_location_bare.include?(pars[:par1_name])
      say "There's no #{pars[:par1_name]} nearby."

    # if general conditions are ok, go to custom conditions and actions
    else
      custom_actions_resuls = true
      custom_action.each do |a|
        custom_actions_resuls = perform_custom_action_internal(a, pars)
        break unless custom_actions_resuls
      end

      # display custom message for command_alias if custom_actions return true value
      say(command_alias.to_sym, :sym_only => true) if custom_actions_resuls
    end

    return true
  end

  def perform_custom_action_internal(action_alias, pars)
    cmd, obj = action_alias.split(' ', 2) 

    # if there are action-specifi conditions and some of them ends false, don't perform actions
    return verify_specific_condition(obj) if (cmd == 'verify')

    # PS: might use case instead of if, but we might need to use regular expressions
    # 'say' custom action is used for special messages, not for command_alias-related message
    if (cmd == 'say') && (! obj.empty?)
      say obj.to_sym, :sym_only => true
    elsif (cmd == 'remove')
      self.game.things[obj].location = nil
    elsif (cmd == 'add')
      self.game.things[obj].location = 'i'
    elsif (cmd == 'visible')
      self.game.things[obj].visible = true
    elsif (cmd == 'set')
      what, old, new = obj.split(' ')

      if (what == 'message')
        Message.replace(old, new)

      elsif (what.split('-')[0] == 'description')
        description_type = what.split('-')[1]
        if (description_type == 'thing')
          @game.things[old].description = Message::find_by_alias(new)
        elsif (description_type == 'location')
          @game.locations[old].description = Message::find_by_alias(new)
        end

      elsif (what.split('-')[0] == 'constraint')
        constraint_type = what.split('-')[1]
        if (constraint_type == 'boolean')
          @constraints['boolean'][old] = new
        elsif (constraint_type == 'location')
          (new == 'nil') ? @constraints['locations'].delete(old) : @constraints['locations'][old] = Message::find_by_alias(new)
        end
      else
        raise "Unknown type of set criterion"
      end
    # suppress usual say command_alias
    elsif (cmd == 'quiet')
      return false
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
      result = (@game.things[data[0]].location == data[1])
      say(data[2].to_sym, :sym_only => true) if ((result == false) and data[2])
      return result
    # is certain constraint set in certain way?
    elsif (condition_type == 'boolean')
      # boolean condition can have a parameter - in that case, we'll compare constraint with it
      result = (data[1].nil? ? @constraints['boolean'][data[0]] : (@constraints['boolean'][data[0]] == data[1]))
      say(data[2].to_sym, :sym_only => true) if ((result == false) and data[2])
      return result
    else
      raise 'unknown condition type'
    end
  end

  # divide line into command and parameters and call command-related function
  def process_line(line)
    # if you don't get any text, do nothing
    return false if line.empty?

    if %w{ h help }.include?(line)
      help_file = File.open('README')
      puts ""
      while (row = help_file.gets) do
        break if (row.chomp == 'Development notes:')
        print(row.chomp.empty? ? row : row.chop_to_lines)
      end
      help_file.close
      return
    end

    # PS: this could be extended into adding extra lines before or after the cursor
    if (line =~ /^extended prompt (\w+)$/)
      case $1.downcase
        when 'on' then 
          @switches[:extended_prompt] = true
          say 'extended prompt activated'
        when 'off' then
          @switches[:extended_prompt] = false
          say 'extended prompt deactivated'
        else
          say 'extended prompt: invalid parameter'
      end
      return false
    end

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

    # yet another update: if we have two parameters, is it actually one object? if not, split them
    if (line_pars.length == 2) && self.active_objects.include?(line_pars.join(" "))
      line_pars = [ line_pars.join("_") ]
    end

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
              say "Which #{par} do you mean: #{choosen_item}, #{item} or something else?"
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

    # construct command_alias, this is used to identify custom actions
    # get conjunction for command
    if not line_pars.is_a?(Array)
      command_alias = "#{command}_#{line_pars}"
    elsif (line_pars.size <= 1)
      command_alias = "#{command}_#{line_pars.shift}"
    else
      conjunction = { 'use' => 'on', 'give' => 'to', 'ask' => 'about' }[command]

      if conjunction
        command_alias = [ command, line_pars[0], conjunction, line_pars[1] ].join('_')
      else
        command_alias = ([command] + [line_pars]).join('_')
      end
    end

    # add command into log so we can create a savegame from it later
    @game.log_command(command_alias.tr('_',' ')) unless (line =~ /^(save|load)/)

    # display results of parsing
    # puts "command [#{command}]"; puts "line pars [#{line_pars.is_a?(Array) ? line_pars.join(", ") : line_pars}]"; puts "command alias: [#{command_alias}]"

    # process command: 1. search for a custom action 
    unless self.perform_custom_action(command_alias, command, line_pars)
      # 2. search for a message (basically an action that just says something)
      # PS: can't use say with :sym_only, because we're checking if sym exists
      msg = Message.find_by_alias(command_alias)
      if msg
        say msg
      # 3. send to command-name method or print an error
      elsif self.respond_to?(command)
        self.send(command, line_pars)
      else
        say :what_a_gibberish
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

  line = Readline.readline(game_player.prompt(), true) # add_hist = true
  Readline::HISTORY.pop if line.empty?

  game_player.process_line(line)
end
