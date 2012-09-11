begin
  require 'cfpropertylist'
rescue LoadError
  require 'rubygems'
  require 'cfpropertylist'
end

# Adds to_rb functionality to return native ruby types rather than CFTypes
module CFPropertyList
  class CFDictionary
    def to_rb
      hash_data = {}
      value.keys.each do |key|
        hash_data[key] = value[key].to_hash
      end
      hash_data
    end
  end
  class CFType
    def to_hash
      self.value
    end
  end
  class CFArray
    def to_hash
      hash_data = []
      value.each do |obj|
        hash_data << obj.to_hash
      end
      hash_data
    end
  end
end
