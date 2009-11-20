
class GameData

  CUSTOM_ACTIONS = {"give_jug_to_priest"=>["verify boolean jug_contains_holy_water true talk_to_priest", "remove jug", "set message talk_to_priest talk_to_priest_3"], "use_shining_sword_on_grelok"=>["exit"], "use_chapel_key_on_chapel_door"=>["verify boolean zombie_blocks_chapel_door false constraint_chapel_door_blocked", "set constraint-boolean chapel_door_locked false", "set constraint-location chapel-e nil", "remove chapel_key", "set description-thing chapel_door description_chapel_door_2"], "use_jug_on_basin"=>["verify boolean jug_contains_holy_water false error_jug_is_full", "set constraint-boolean jug_contains_holy_water true", "set description-thing jug description_jug_contains_holy_water"], "drink_from_jug"=>["verify boolean jug_contains_holy_water true use_jug_empty", "say use_jug_full", "quiet"], "give_gemstone_shards_to_blacksmith"=>["verify location rusty_sword i error_no_rusty_sword", "remove gemstone_shards", "remove rusty_sword", "add shining_sword"], "use_rusty_sword_on_zombie"=>["verify boolean zombie_blocks_chapel_door true use_rusty_sword_on_zombie", "set constraint-boolean zombie_blocks_chapel_door false", "set constraint-location chapel-e constraint_chapel_door_locked", "set description-location chapel description_chapel_2", "set description-thing zombie description_zombie_2", "set description-thing open_grave description_open_grave_2", "say use_rusty_sword_on_zombie", "set message use_rusty_sword_on_zombie use_rusty_sword_on_zombie_2", "quiet"], "talk_to_priest"=>["verify boolean given_quest_holy_water false talk_to_priest", "set constraint-boolean given_quest_holy_water true", "add jug", "add chapel_key", "say talk_to_priest", "set message talk_to_priest talk_to_priest_2", "quiet"], "give_gemstone_to_wizard"=>["remove gemstone", "visible gemstone_shards"], "look_at_rubble"=>["say look_at_rubble", "verify location gemstone mountain", "visible gemstone", "say look_at_rubble_hidden", "quiet"]}

  CONSTRAINTS = {"boolean"=>{"chapel_door_locked"=>"true", "given_quest_holy_water"=>"false", "zombie_blocks_chapel_door"=>"true", "jug_contains_holy_water"=>"false"}, "locations"=>{"chapel-e"=>"Chapel door is blocked by zombie."}}

  COMMANDS = {"display_inventory"=>["i", "inv", "inventory"], "go_east"=>["e", "east"], "load_game"=>["load", "restore"], "go_south"=>["s", "south"], "ask"=>["ask"], "quit_game"=>["quit", "exit"], "talk_to"=>["tt", "talk", "talk to"], "pick_up"=>["p", "pick", "t", "take"], "go_north"=>["n", "north"], "drop"=>["d", "drop"], "use"=>["u", "use"], "look_at"=>["l", "look", "e", "examine"], "save_game"=>["save"], "attack"=>["a", "attack", "slay"], "give"=>["g", "give"], "go_west"=>["w", "west"]}

  THINGS = {"wizards_tower"=>{"location"=>"swamp", "alias"=>"wizards_tower", "description"=>"a small wizards tower on a small island in the middle of swamp", "pickable"=>false}, "pebble"=>{"location"=>"plain", "alias"=>"pebble", "description"=>"a tiny pebble", "pickable"=>true}, "gemstone_shards"=>{"location"=>"swamp", "alias"=>"gemstone_shards", "description"=>"two gemstone shards emanating strange glow", "pickable"=>true, "visible"=>false}, "wizard"=>{"location"=>"swamp", "alias"=>"wizard", "description"=>"a tall bespectacled wizard lost in his thoughts", "pickable"=>false}, "gemstone"=>{"location"=>"mountain", "alias"=>"gemstone", "description"=>"beautiful gemstone emanating strange glow", "pickable"=>true, "visible"=>false}, "chapel_door"=>{"location"=>"chapel", "alias"=>"chapel_door", "description"=>"a door to chapel. It's locked", "pickable"=>false}, "open_grave"=>{"location"=>"chapel", "alias"=>"open_grave", "description"=>"an open grave near the path to the chapel", "pickable"=>false}, "grelok"=>{"location"=>"mountain", "alias"=>"grelok", "description"=>"Grelok the Gruesome spewing heresies", "pickable"=>false}, "jug"=>{"location"=>nil, "alias"=>"jug", "description"=>"an empty clay jug with \"XXX\" written on it. It reeks of cheap booze", "pickable"=>true}, "zombie"=>{"location"=>"chapel", "alias"=>"zombie", "description"=>"zombie blocking the entrance to the chapel", "pickable"=>false}, "blacksmith"=>{"location"=>"town", "alias"=>"blacksmith", "description"=>"a stout blackmith working in front of his smithy", "pickable"=>false}, "chapel_key"=>{"location"=>nil, "alias"=>"chapel_key", "description"=>"a large brass key. It's sticky and smells like it's been soaked in beer. There's a tag on it that says: 'chapel'", "pickable"=>true}, "basin"=>{"location"=>"chapel_interior", "alias"=>"basin", "description"=>"a marble basin full of holy water", "pickable"=>false}, "priest"=>{"location"=>"town", "alias"=>"priest", "description"=>"a small, chubby priest sitting under a tree. He looks like he's been drinking", "pickable"=>false}, "standing_stone"=>{"location"=>"plain", "alias"=>"standing_stone", "description"=>"a huge menhir standing in the middle of the plain, at the Great crossroads", "pickable"=>false}, "rubble"=>{"location"=>"mountain", "alias"=>"rubble", "description"=>"rubble of big and small stones near the path", "pickable"=>false}, "shining_sword"=>{"location"=>nil, "alias"=>"shining_sword", "description"=>"your sword forged with gemstone shards. It's shining", "pickable"=>true}, "rusty_sword"=>{"location"=>"i", "alias"=>"rusty_sword", "description"=>"your trusty rusty sword", "pickable"=>true}}

  LOCATIONS = {"chapel_interior"=>{"directions"=>{"w"=>"chapel"}, "name"=>"Inside chapel", "alias"=>"chapel_interior", "description"=>"You're in the small, dark chapel. Benches are damp and half-rotten, altar is owergrown with ivy. The ony one relatively undamaged thing here is the holy water basin, standing on a marble pillar by the entrance."}, "plain"=>{"directions"=>{"w"=>"swamp", "n"=>"mountain", "e"=>"chapel", "s"=>"town"}, "name"=>"Plain", "alias"=>"plain", "description"=>"You are standing in the middle of wide plain, on the crossroads marked by gigantic standing stone. Tall green grass is blowing in the wind."}, "swamp"=>{"directions"=>{"e"=>"plain"}, "name"=>"Swamp", "alias"=>"swamp", "description"=>"You're in gloomy green Swamp of Despair. There's only bleak swamp around here, except for tall white-stone tower on a small grass island in its midst. There's a small window near the top of the tower and from him an eccentric wizard is eyeing you suspiciously."}, "chapel"=>{"directions"=>{"w"=>"plain", "e"=>"chapel_interior"}, "name"=>"chapel", "alias"=>"chapel", "description"=>"You're standing in front of an abandoned chapel. It is surrounded by a graveyard, half-covered in mist. There's a zombie standing right in front of the entrance to the chapel."}, "mountain"=>{"directions"=>{"s"=>"plain"}, "name"=>"Mountain", "alias"=>"mountain", "description"=>"You are high in the mountains, in the realm of Grelok. The sky is red and dusky, the wind is cold and howling, the earth is covered with black volcano ashes."}, "town"=>{"directions"=>{"n"=>"plain"}, "name"=>"Town", "alias"=>"town", "description"=>"You're in little town of Homeburg. It's main square is very pictoresque, were it not for the gallows where the orcs are hanging by their throats. Everything is closed except for the smithy."}}

  MESSAGES = {"use_jug_empty"=>"The jug is empty.", "give_jug_to_priest"=>"\"You made it! Thank you, my child. Have you taken care of the zombies? Great, I'll rest some more and then I'll be on my way back to the chapel.\"", "move_zombie"=>"No, it's a bad idea to come too close to zombies unprotected, they can bite you.", "use_shining_sword_on_grelok"=>"Grelok lets out a sinister laugh when you attack him, but when you cut off both of his legs at once, he yells: 'No! The legendary Eye of Grub! You can't beat me!' and conjures army of demons at his side. Clouds cover the sky and start raining fire, demons scream and Grelok chants a terrible curse. You throw the sword into his wide-opened mouth and it makes his head explode. The daemons' army turn into stone. \nSuddenly sky is blue again and refreshing cold breeze returns back to the mountains. The flock of pitch-black ravens feasts on the Grelok's squishy remains.\n\nCongratulations, the victory is yours!\n\nTHE END\n\n", "error_jug_is_full"=>"The jug is already full.", "use_jug_full"=>"You don't want to drink holy water.", "talk_to_blacksmith"=>"Blacksmith smiles at you. He's sweaty and obviously very tired. \"Greetings, stranger! Sorry but I can't chat, I'm very busy making swords for the army.\"", "use_chapel_key_on_chapel_door"=>"You unlocked the chapel door. The key got stuck in it and you can't get it out.", "use_rusty_sword_on_zombie_2"=>"Why? It's already trapped in the grave.", "use_jug_on_basin"=>"You filled the jug to the brim with holy water.", "ask_grelok_about_anything"=>"\"I don't have time for your silly questions, human!\"", "give_anything_to_wizard"=>"\"I don't want it.\"", "ask_blacksmith_about_anything"=>"\"I'm afraid I can't help you with that, son.\"", "give_gemstone_to_blacksmith"=>"Blacksmith examines the gemstone. 'Beautiful piece of rock it is, and magical, no doubt about it. I could forge it into your sword, but I cannot work for free! Sorry, but times are hard.'", "ask_blacksmith_about_grelok"=>"\"He's an evil wizard who descended from frozen mountains. They say that normal weapons can't hurt him. You'll need a magic sword in order to stand a chance against him.\"", "use_rusty_sword_on_grelok"=>"You stab, slash and swing your old sword at Grelok, but it doesn't have any effect. 'You fool, your puny weapon can harm me!' he laughs at you and continue to spew heresies.", "error_no_rusty_sword"=>"Where's your sword, son? How am I supposed to reforge it if you don't have it?", "give_gemstone_shards_to_blacksmith"=>"'I'll forge one half of this gemstone into your sword and take the other half as a payment for my hard work' says blacksmith. He takes your sword and closes himself in the smithy. Much later he comes out, tired and drenched in sweat, and hands out the reforged sword, which emanates strange blue glow.", "look_at_rubble_hidden"=>"There's a beautiful gemstone glittering in the rubble.", "description_chapel_door_2"=>"a door to chapel", "use_rusty_sword_on_zombie"=>"You furiously attack zombie with your sword. As it tries to avoid your attack, it stumbles and falls into an open grave.", "gibberish1"=>"Mighty Grognak is confused by this gibberish.", "give_anything_to_grelok"=>"\"I don't have time for your silly gifts, human!\"", "give_anything_to_blacksmith"=>"\"Keep it, son. I don't want it.\"", "constraint_chapel_door_locked"=>"Chapel door is locked.", "gibberish2"=>"I do not understand what are you trying to do.", "description_jug_contains_holy_water"=>"a jug full of holy water. However, it still reeks of booze a little", "push_zombie"=>"No, it's a bad idea to come too close to zombies unprotected, they can bite you.", "push_zombie_to_open_grave"=>"No, it's a bad idea to come too close to zombies unprotected, they can bite you.", "gibberish3"=>"Sorry, I do not speak gibberish.", "talk_to_priest_2"=>"\"Please hurry and bring me some holy water.\"", "talk_to_priest"=>"Priest smiles at you. \"My child, help me! Fill this vessel with holy water from the chapel on the north-east I had to abandon\" He hands you a vessel, which is actually just a lousy jug, and large brass key.", "constraint_chapel_door_blocked"=>"Chapel door is blocked by zombie.", "description_jug_contains_nothing"=>"an empty clay jug with \"XXX\" written on it. It reeks of cheap booze", "talk_to_priest_3"=>"\"Thank you again, my child.\"", "ask_wizard_about_anything"=>"\"I dunno, lemme check wiki... oh, it hasn't been invented yet! Never mind, then.\"", "description_open_grave_2"=>"an open grave near the path to the chapel with zombie trapped in it", "description_zombie_2"=>"zombie trapped in the open grave", "talk_to_grelok"=>"Grelok lets out a terrible roar: \"You are not worthy to speak to Grelok the Gruesome!\"", "give_gemstone_to_wizard"=>"You took gemstone out of your pocket. Wizard's eyes glitter and he yells: 'Behold, the Eye of Grub!', he raises his hand and the gemstone flows from you to him. He chants and chants, gets kinda boring, but suddenly there's loud BANG and gemstone splits into two and falls on ground. Wizard looks surprised for a moment, but then he says: 'That's exactly what I had in mind. Take it and off with you!'", "talk_to_wizard"=>"Wizard yells at you angrily: \"Go away, there's nothing to see here!\"", "description_chapel_2"=>"You're standing in front of an abandoned chapel. It is surrounded by a graveyard, half-covered in mist. You heard strange noises from the mist: shuffling of feet and heavy breathing.", "look_at_rubble"=>"It's a rubble of big and small stones near the path."}

end
