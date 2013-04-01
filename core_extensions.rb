
# this file contains extensions to core ruby classes

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
