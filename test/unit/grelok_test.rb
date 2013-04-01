require 'test_helper'

class GrelokTest < Test::Unit::TestCase

  context "At the beginning, Grognak" do
    setup do
      @player = Player.new
    end

    should "carry rusty sword" do
      assert @player.inventory.include?('rusty_sword'), "Dude, where's my sword?"
    end
  end

end
