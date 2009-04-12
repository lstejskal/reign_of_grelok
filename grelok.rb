
# The story originates from Fallout 3 minigame - Reign of Grelok beta

# to do list:
# - make object in game context-sensitive 
# (1: rusty sword == sword if there are not other swords around
# 2: if there are both rusty and shining sword, let user pick one)
# - interprocess communication - make GameState and Thing subclasses of Game
# - implement save/load game (could be just a command log)

# PS: there should be a table of constraints and state handling (we should be able to save state)

require 'yaml'

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

  def formatted_directions
    # TO DO: 'x, y and z instead of x,y,z'
    "You can go #{directions.keys.collect{ |k| DIRECTION_SHORTCUTS[k] }.join(', ')}."
  end

  private
    
  def allowed_attr_names
    %w{ alias name description contains directions }  
  end
end

# takes care of a game-related stuff: init, loading, saving...
# displays main menu
class GrelokGame
  attr_accessor :locations, :things
  
  def initialize()
    @locations = load_locations()
    @things = load_things()
    # constraints
    # persons
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

  def initialize()
    @game = GrelokGame.new
      
    @current_location = 'plain'
    @previous_location = nil
    
    @action_type = nil
    
    @constraints = { :chapel_unlocked => false }
    @error_msg = nil
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
end

# main program loop
gs = GameState.new

line = nil

while (line !~ /^(quit|exit)$/) do
  # if you changed location, print look-around
  if (gs.current_location != gs.previous_location)
    gs.print_info 
    gs.previous_location = gs.current_location
  end
  
  print '> '
  line = readline
  line.chomp!

  # process_line  

  # 1st tier - single-word commands

  # process direction - go north/south/east/west
  if %w{ n s e w north south east west }.include?(line)
    gs.action_type = :walk
    direction = line.slice(0..0)

    if gs.location.directions.has_key?(direction)
      if gs.allowed_by_constraints?(:direction => direction)
        gs.current_location = gs.location.directions[direction]
      else
        puts gs.error_msg
      end
    else
      puts 'You can\'t go that way.'
    end
  # display content of inventory
  elsif %w{i inv inventory }.include?(line)
    if gs.inventory.empty?
      puts "You don't have anything."
    else
      puts gs.things_in_location('i')
    end

  # re-display description of the location (the look-around)
  elsif %w{ l look info }.include?(line)
    gs.previous_location = nil

  # pray - for help aka manual

  # 2nd tier
  
  # examine object - display its description
  # refactor to Thing.lookable? pickable? dropable?
  elsif (line =~ /^(l|look at|e|examine) (.+)$/)
    gs.action_type = :look
    thing_name = $2
    thing_alias = thing_name.gsub(/ +/, '_')

    # general constraint: thing has to be in current_location or inventory
    if gs.active_things.keys.include?(thing_alias)
      puts "It's #{gs.active_things[thing_alias].description}."
    else
      puts "You can't see any #{thing_name} here."
    end

    # check constraints
    if (gs.current_location == 'mountain') and (thing_alias == 'rubble')
      gs.game.things['gemstone'].visible = true
      puts 'You notice a beautiful gemstone lying in the rubble.'
    end
    
  # take object in certain location
  elsif (line =~ /^(t|take|p|pick up) (.+)$/)
    gs.action_type = :pick_up
    thing_name = $2
    thing_alias = thing_name.gsub(/ +/, '_')
    
    if gs.pickable?(thing_alias) and gs.game.things[thing_alias].visible
      gs.pick_up(thing_alias)
      puts "You picked up #{thing_name}."
    # if it's already in you inventory
    elsif gs.inventory.include?(thing_alias)
      puts "You already carry #{thing_name}."
    else
      puts "You can't pick up #{thing_name}."
    end
    
  # drop object in certain location
  elsif (line =~ /^(d|drop) (.+)$/)
    gs.action_type = :drop
    thing_name = $2
    thing_alias = thing_name.gsub(/ +/, '_')

    if gs.droppable?(thing_alias)      
      puts "You dropped #{thing_name}." if gs.drop(thing_alias)
    else
      puts "You don't carry #{thing_name}."
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
      if (gs.game.things[thing_alias].location != 'i')
        puts "You don't carry #{thing_name}."
      # are you in correct location
      elsif (gs.current_location != 'swamp')
        puts "There's no #{give_to_name} nearby."
      # ok, give the item away
      else 
        gs.game.things[thing_alias].location = nil
        gs.game.things['gemstone_shards'].visible = true
        puts "You took gemstone out of your pocket. Wizard's eyes glitter and he yells: 'Behold, the Eye of Grub!', he raises his hand and the gemstone flows from you to him. He chants and chants, gets kinda boring, but suddenly there's loud BANG and gemstone splits into two and falls on ground. Wizard looks surprised for a moment, but then he says: 'That's exactly what I had in mind. Take it and off with you!'"
      end

    # try to give gemstone to smith
    # to do: in general if you have the thing (or is in current_location) and give_to is in current location
    elsif (thing_alias == 'gemstone') and (give_to == 'blacksmith') 
      # do you have that thing?
      if (gs.game.things[thing_alias].location != 'i')
        puts "You don't carry #{thing_name}."
      # are you in correct location
      elsif (gs.current_location != 'town')
        puts "There's no #{give_to_name} nearby."
      # ok, give the item away
      else 
        puts "Blacksmith examines the gemstone. 'Beautiful piece of rock it is, and magical, no doubt about it. I could forge it into your sword, but I cannot work for free! Sorry, but times are hard.'"
      end

    # to do: in general if you have the thing (or is in current_location) and give_to is in current location
    elsif (thing_alias == 'gemstone_shards') and (give_to == 'blacksmith') 
      # do you have that thing?
      if (gs.game.things[thing_alias].location != 'i')
        puts "You don't carry #{thing_name}."
      # are you in correct location
      elsif (gs.current_location != 'town')
        puts "There's no #{give_to_name} nearby."
      # ok, give the item away
      else 
        # PS: to do: instead of visible switch, why don't you set thing.location to nil? that's the same, isn't it?
        # on the other hand, thing location should be kept (shining_sword should be in inventory, but invisible)
        gs.game.things[thing_alias].location = nil
        gs.game.things['rusty_sword'].location = nil
        gs.game.things['shining_sword'].location = 'i'
        puts "'I'll forge one half of this gemstone into your sword and take the other half as a payment for my hard work' says blacksmith. He takes your sword and closes himself in the smithy. Much later he comes out, tired and drenched in sweat, and hands out the reforged sword, which emanates strange blue glow."
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
      if (gs.game.things[thing_alias].location != 'i')
        puts "You don't carry #{thing_name}."
      # also check if it's a valid thing
      elsif (gs.current_location != 'mountain')
        puts "There's no #{use_on_alias} nearby."
      else
        puts "You stab, slash and swing your old sword at Grelok, but it doesn't have any effect. 'You fool, your puny weapon can harm me!' he laughs at you and continue to spew heresies."
      end

    elsif (thing_alias == 'shining_sword') and (use_on == 'grelok')
      if (gs.game.things[thing_alias].location != 'i')
        puts "You don't carry #{thing_name}."
      # also check if it's a valid thing
      elsif (gs.current_location != gs.game.things[use_on].location)
        puts "There's no #{use_on_alias} nearby."
      else
        puts "Grelok lets out a sinister laugh when you attack him, but when you cut off both of his legs at once, he yells: 'No! The legendary Eye of Grub! You can't beat me!' and conjures army of demons at his side. Clouds cover the sky and start raining fire, demons scream and Grelok chants a terrible curse. You throw the sword into his wide-opened mouth and it makes his head explode. The daemons' army turn into stone. \nSuddenly sky is blue again and refreshing cold breeze returns back to the mountains. The flock of pitch-black ravens feasts on the Grelok's squishy remains.\n\nCongratulations, the victory is yours!\n\nTHE END\n\n"
        exit
      end
    
    else
      puts "Nothing happens."
    end

  else
    puts 'Unknown command.' unless (line.empty? || line == 'exit' || line == 'quit')
  end

end

puts 'See ya!'
