require "date"
require "nkf"
require "set"
require "stringio"

module IpaReader
  module Plist
    module Binary
      # Encodes +obj+ as a binary property list. If +obj+ is an Array, Hash, or
      # Set, the property list includes its contents.
      def self.binary_plist(obj)
        encoded_objs = flatten_collection(obj)
        ref_byte_size = min_byte_size(encoded_objs.length - 1)
        encoded_objs.collect! {|o| binary_plist_obj(o, ref_byte_size)}
        # Write header and encoded objects.
        plist = "bplist00" + encoded_objs.join
        # Write offset table.
        offset_table_addr = plist.length
        offset = 8
        offset_table = []
        encoded_objs.each do |o|
          offset_table << offset
          offset += o.length
        end
        offset_byte_size = min_byte_size(offset)
        offset_table.each do |offset|
          plist += pack_int(offset, offset_byte_size)
        end
        # Write trailer.
        plist += "\0\0\0\0\0\0" # Six unused bytes
        plist += [
          offset_byte_size,
          ref_byte_size,
          encoded_objs.length >> 32, encoded_objs.length & 0xffffffff,
          0, 0, # Index of root object
          offset_table_addr >> 32, offset_table_addr & 0xffffffff
        ].pack("CCNNNNNN")
        plist
      end
    
      def self.decode_binary_plist(plist)
        # Check header.
        unless plist[0, 6] == "bplist"
          raise ArgumentError, "argument is not a binary property list"
        end
        version = plist[6, 2]
        unless version == "00"
          raise ArgumentError,
            "don't know how to decode format version #{version}"
        end
        # Read trailer.
        trailer = plist[-26, 26].unpack("CCNNNNNN")
        offset_byte_size    = trailer[0]
        ref_byte_size       = trailer[1]
        encoded_objs_length = combine_ints(32, trailer[2], trailer[3])
        root_index          = combine_ints(32, trailer[4], trailer[5])
        offset_table_addr   = combine_ints(32, trailer[6], trailer[7])
        # Decode objects.
        root_offset = offset_for_index(plist, offset_table_addr,
          offset_byte_size, root_index)
        root_obj = decode_binary_plist_obj(plist, root_offset, ref_byte_size)
        unflatten_collection(root_obj, [root_obj], plist, offset_table_addr,
          offset_byte_size, ref_byte_size)
      end
    
    private
    
      # These marker bytes are prefixed to objects in a binary property list to
      # indicate the type of the object.
      CFBinaryPlistMarkerNull = 0x00 # :nodoc:
      CFBinaryPlistMarkerFalse = 0x08 # :nodoc:
      CFBinaryPlistMarkerTrue = 0x09 # :nodoc:
      CFBinaryPlistMarkerFill = 0x0F # :nodoc:
      CFBinaryPlistMarkerInt = 0x10 # :nodoc:
      CFBinaryPlistMarkerReal = 0x20 # :nodoc:
      CFBinaryPlistMarkerDate = 0x33 # :nodoc:
      CFBinaryPlistMarkerData = 0x40 # :nodoc:
      CFBinaryPlistMarkerASCIIString = 0x50 # :nodoc:
      CFBinaryPlistMarkerUnicode16String = 0x60 # :nodoc:
      CFBinaryPlistMarkerUID = 0x80 # :nodoc:
      CFBinaryPlistMarkerArray = 0xA0 # :nodoc:
      CFBinaryPlistMarkerSet = 0xC0 # :nodoc:
      CFBinaryPlistMarkerDict = 0xD0 # :nodoc:
    
      # POSIX uses a reference time of 1970-01-01T00:00:00Z; Cocoa's reference
      # time is in 2001. This interval is for converting between the two.
      NSTimeIntervalSince1970 = 978307200.0 # :nodoc:
    
      # Takes an object (nominally a collection, like an Array, Set, or Hash, but
      # any object is acceptable) and flattens it into a one-dimensional array.
      # Non-collection objects appear in the array as-is, but the contents of
      # Arrays, Sets, and Hashes are modified like so: (1) The contents of the
      # collection are added, one-by-one, to the one-dimensional array. (2) The
      # collection itself is modified so that it contains indexes pointing to the
      # objects in the one-dimensional array. Here's an example with an Array:
      #
      #   ary = [:a, :b, :c]
      #   flatten_collection(ary) # => [[1, 2, 3], :a, :b, :c]
      #
      # In the case of a Hash, keys and values are both appended to the one-
      # dimensional array and then replaced with indexes.
      #
      #   hsh = {:a => "blue", :b => "purple", :c => "green"}
      #   flatten_collection(hsh)
      #   # => [{1 => 2, 3 => 4, 5 => 6}, :a, "blue", :b, "purple", :c, "green"]
      #
      # An object will never be added to the one-dimensional array twice. If a
      # collection refers to an object more than once, the object will be added
      # to the one-dimensional array only once.
      #
      #   ary = [:a, :a, :a]
      #   flatten_collection(ary) # => [[1, 1, 1], :a]
      #
      # The +obj_list+ and +id_refs+ parameters are private; they're used for
      # descending into sub-collections recursively.
      def self.flatten_collection(collection, obj_list = [], id_refs = {})
        case collection
        when Array, Set
          if id_refs[collection.object_id]
            return obj_list[id_refs[collection.object_id]]
          end
          obj_refs = collection.class.new
          id_refs[collection.object_id] = obj_list.length
          obj_list << obj_refs
          collection.each do |obj|
            flatten_collection(obj, obj_list, id_refs)
            obj_refs << id_refs[obj.object_id]
          end
          return obj_list
        when Hash
          if id_refs[collection.object_id]
            return obj_list[id_refs[collection.object_id]]
          end
          obj_refs = {}
          id_refs[collection.object_id] = obj_list.length
          obj_list << obj_refs
          collection.each do |key, value|
            key = key.to_s if key.is_a?(Symbol)
            flatten_collection(key, obj_list, id_refs)
            flatten_collection(value, obj_list, id_refs)
            obj_refs[id_refs[key.object_id]] = id_refs[value.object_id]
          end
          return obj_list
        else
          unless id_refs[collection.object_id]
            id_refs[collection.object_id] = obj_list.length
            obj_list << collection
          end
          return obj_list
        end
      end
    
      def self.unflatten_collection(collection, obj_list, plist,
        offset_table_addr, offset_byte_size, ref_byte_size)
        case collection
        when Array, Set
          collection.collect! do |index|
            if obj = obj_list[index]
              obj
            else
              offset = offset_for_index(plist, offset_table_addr, offset_byte_size,
                index)
              obj = decode_binary_plist_obj(plist, offset, ref_byte_size)
              obj_list[index] = obj
              unflatten_collection(obj, obj_list, plist, offset_table_addr,
                offset_byte_size, ref_byte_size)
            end
          end
        when Hash
          hsh = {}
          collection.each do |key, value|
            unless key_obj = obj_list[key]
              offset = offset_for_index(plist, offset_table_addr, offset_byte_size,
                key)
              key_obj = decode_binary_plist_obj(plist, offset, ref_byte_size)
              obj_list[key] = key_obj
              key_obj = unflatten_collection(key_obj, obj_list, plist,
                offset_table_addr, offset_byte_size, ref_byte_size)
            end
            unless value_obj = obj_list[value]
              offset = offset_for_index(plist, offset_table_addr, offset_byte_size,
                value)
              value_obj = decode_binary_plist_obj(plist, offset, ref_byte_size)
              obj_list[value] = value_obj
              value_obj = unflatten_collection(value_obj, obj_list, plist,
                offset_table_addr, offset_byte_size, ref_byte_size)
            end
            hsh[key_obj] = value_obj
          end
          collection.replace(hsh)
        end
        return collection
      end
    
      # Returns a binary property list fragment that represents +obj+. The
      # returned string is not a complete property list, just a fragment that
      # describes +obj+, and is not useful without a header, offset table, and
      # trailer.
      #
      # The following classes are recognized: String, Float, Integer, the Boolean
      # classes, Time, IO, StringIO, Array, Set, and Hash. IO and StringIO
      # objects are rewound, read, and the contents stored as data (i.e., Cocoa
      # applications will decode them as NSData). All other classes are dumped
      # with Marshal and stored as data.
      #
      # Note that subclasses of the supported classes will be encoded as though
      # they were the supported superclass. Thus, a subclass of (for example)
      # String will be encoded and decoded as a String, not as the subclass:
      #
      #   class ExampleString < String
      #     ...
      #   end
      #
      #   s = ExampleString.new("disquieting plantlike mystery")
      #   encoded_s = binary_plist_obj(s)
      #   decoded_s = decode_binary_plist_obj(encoded_s)
      #   puts decoded_s.class # => String
      #
      # +ref_byte_size+ is the number of bytes to use for storing references to
      # other objects.
      def self.binary_plist_obj(obj, ref_byte_size = 4)
        case obj
        when String
          obj = obj.to_s if obj.is_a?(Symbol)
          # This doesn't really work. NKF's guess method is really, really bad
          # at discovering UTF8 when only a handful of characters are multi-byte.
          encoding = NKF.guess2(obj)
          if encoding == NKF::ASCII && obj =~ /[\x80-\xff]/
            encoding = NKF::UTF8
          end
          if [NKF::ASCII, NKF::BINARY, NKF::UNKNOWN].include?(encoding)
            result = (CFBinaryPlistMarkerASCIIString |
              (obj.length < 15 ? obj.length : 0xf)).chr
            result += binary_plist_obj(obj.length) if obj.length >= 15
            result += obj
            return result
          else
            # Convert to UTF8.
            if encoding == NKF::UTF8
              utf8 = obj
            else
              utf8 = NKF.nkf("-m0 -w", obj)
            end
            # Decode each character's UCS codepoint.
            codepoints = []
            i = 0
            while i < utf8.length
              byte = utf8[i]
              if byte & 0xe0 == 0xc0
                codepoints << ((byte & 0x1f) << 6) + (utf8[i+1] & 0x3f)
                i += 1
              elsif byte & 0xf0 == 0xe0
                codepoints << ((byte & 0xf) << 12) + ((utf8[i+1] & 0x3f) << 6) +
                  (utf8[i+2] & 0x3f)
                i += 2
              elsif byte & 0xf8 == 0xf0
                codepoints << ((byte & 0xe) << 18) + ((utf8[i+1] & 0x3f) << 12) +
                  ((utf8[i+2] & 0x3f) << 6) + (utf8[i+3] & 0x3f)
                i += 3
              else
                codepoints << byte
              end
              if codepoints.last > 0xffff
                raise(ArgumentError, "codepoint too high - only the Basic Multilingual Plane can be encoded")
              end
              i += 1
            end
            # Return string of 16-bit codepoints.
            data = codepoints.pack("n*")
            result = (CFBinaryPlistMarkerUnicode16String |
              (codepoints.length < 15 ? codepoints.length : 0xf)).chr
            result += binary_plist_obj(codepoints.length) if codepoints.length >= 15
            result += data
            return result
          end
        when Float
          return (CFBinaryPlistMarkerReal | 3).chr + [obj].pack("G")
        when Integer
          nbytes = min_byte_size(obj)
          size_bits = { 1 => 0, 2 => 1, 4 => 2, 8 => 3, 16 => 4 }[nbytes]
          return (CFBinaryPlistMarkerInt | size_bits).chr + pack_int(obj, nbytes)
        when TrueClass
          return CFBinaryPlistMarkerTrue.chr
        when FalseClass
          return CFBinaryPlistMarkerFalse.chr
        when Time
          return CFBinaryPlistMarkerDate.chr +
            [obj.to_f - NSTimeIntervalSince1970].pack("G")
        when IO, StringIO
          obj.rewind
          return binary_plist_data(obj.read)
        when Array
          # Must be an array of object references as returned by flatten_collection.
          result = (CFBinaryPlistMarkerArray | (obj.length < 15 ? obj.length : 0xf)).chr
          result += binary_plist_obj(obj.length) if obj.length >= 15
          result += obj.collect! { |i| pack_int(i, ref_byte_size) }.join
        when Set
          # Must be a set of object references as returned by flatten_collection.
          result = (CFBinaryPlistMarkerSet | (obj.length < 15 ? obj.length : 0xf)).chr
          result += binary_plist_obj(obj.length) if obj.length >= 15
          result += obj.to_a.collect! { |i| pack_int(i, ref_byte_size) }.join
        when Hash
          # Must be a table of object references as returned by flatten_collection.
          result = (CFBinaryPlistMarkerDict | (obj.length < 15 ? obj.length : 0xf)).chr
          result += binary_plist_obj(obj.length) if obj.length >= 15
          result += obj.keys.collect! { |i| pack_int(i, ref_byte_size) }.join
          result += obj.values.collect! { |i| pack_int(i, ref_byte_size) }.join
        else
          return binary_plist_data(Marshal.dump(obj))
        end
      end
    
      def self.decode_binary_plist_obj(plist, offset, ref_byte_size)
        case plist[offset]
        when CFBinaryPlistMarkerASCIIString..(CFBinaryPlistMarkerASCIIString | 0xf)
          length, offset = decode_length(plist, offset)
          return plist[offset, length]
        when CFBinaryPlistMarkerUnicode16String..(CFBinaryPlistMarkerUnicode16String | 0xf)
          length, offset = decode_length(plist, offset)
          codepoints = plist[offset, length * 2].unpack("n*")
          str = ""
          codepoints.each do |codepoint|
            if codepoint <= 0x7f
              ch = ' '
              ch[0] = to_i
            elsif codepoint <= 0x7ff
              ch = '  '
              ch[0] = ((codepoint & 0x7c0) >> 6) | 0xc0
              ch[1] = codepoint & 0x3f | 0x80
            else
              ch = '   '
              ch[0] = ((codepoint & 0xf000) >> 12) | 0xe0
              ch[1] = ((codepoint & 0xfc0) >> 6) | 0x80
              ch[2] = codepoint & 0x3f | 0x80
            end
            str << ch
          end
          return str
        when CFBinaryPlistMarkerReal | 3
          return plist[offset+1, 8].unpack("G").first
        when CFBinaryPlistMarkerInt..(CFBinaryPlistMarkerInt | 0xf)
          num_bytes = 2 ** (plist[offset] & 0xf)
          return unpack_int(plist[offset+1, num_bytes])
        when CFBinaryPlistMarkerTrue
          return true
        when CFBinaryPlistMarkerFalse
          return false
        when CFBinaryPlistMarkerDate
          secs = plist[offset+1, 8].unpack("G").first + NSTimeIntervalSince1970
          return Time.at(secs)
        when CFBinaryPlistMarkerData..(CFBinaryPlistMarkerData | 0xf)
          length, offset = decode_length(plist, offset)
          return StringIO.new(plist[offset, length])
        when CFBinaryPlistMarkerArray..(CFBinaryPlistMarkerArray | 0xf)
          ary = []
          length, offset = decode_length(plist, offset)
          length.times do
            ary << unpack_int(plist[offset, ref_byte_size])
            offset += ref_byte_size
          end
          return ary
        when CFBinaryPlistMarkerDict..(CFBinaryPlistMarkerDict | 0xf)
          hsh = {}
          keys = []
          length, offset = decode_length(plist, offset)
          length.times do
            keys << unpack_int(plist[offset, ref_byte_size])
            offset += ref_byte_size
          end
          length.times do |i|
            hsh[keys[i]] = unpack_int(plist[offset, ref_byte_size])
            offset += ref_byte_size
          end
          return hsh
        end
      end
    
      # Returns a binary property list fragment that represents a data object
      # with the contents of the string +data+. A Cocoa application would decode
      # this fragment as NSData. Like binary_plist_obj, the value returned by
      # this method is not usable by itself; it is only useful as part of a
      # complete binary property list with a header, offset table, and trailer.
      def self.binary_plist_data(data)
        result = (CFBinaryPlistMarkerData |
          (data.length < 15 ? data.length : 0xf)).chr
        result += binary_plist_obj(data.length) if data.length > 15
        result += data
        return result
      end
    
      # Determines the minimum number of bytes that is a power of two and can
      # represent the integer +i+. Raises a RangeError if the number of bytes
      # exceeds 16. Note that the property list format considers integers of 1,
      # 2, and 4 bytes to be unsigned, while 8- and 16-byte integers are signed;
      # thus negative integers will always require at least 8 bytes of storage.
      def self.min_byte_size(i)
        if i < 0
          i = i.abs - 1
        else
          if i <= 0xff
            return 1
          elsif i <= 0xffff
            return 2
          elsif i <= 0xffffffff
            return 4
          end
        end      
        if i <= 0x7fffffffffffffff
          return 8
        elsif i <= 0x7fffffffffffffffffffffffffffffff
          return 16
        end
        raise(RangeError, "integer too big - exceeds 128 bits")
      end
    
      # Packs an integer +i+ into its binary representation in the specified
      # number of bytes. Byte order is big-endian. Negative integers cannot be
      # stored in 1, 2, or 4 bytes.
      def self.pack_int(i, num_bytes)
        if i < 0 && num_bytes < 8
          raise(ArgumentError, "negative integers require 8 or 16 bytes of storage")
        end
        case num_bytes
        when 1
          [i].pack("c")
        when 2
          [i].pack("n")
        when 4
          [i].pack("N")
        when 8
          [(i >> 32) & 0xffffffff, i & 0xffffffff].pack("NN")
        when 16
          [i >> 96, (i >> 64) & 0xffffffff, (i >> 32) & 0xffffffff,
            i & 0xffffffff].pack("NNNN")
        else
          raise(ArgumentError, "num_bytes must be 1, 2, 4, 8, or 16")
        end
      end
    
      def self.combine_ints(num_bits, *ints)
        i = ints.pop
        shift_bits = num_bits
        ints.reverse.each do |i_part|
          i += i_part << shift_bits
          shift_bits += num_bits
        end
        return i
      end
    
      def self.offset_for_index(plist, table_addr, offset_byte_size, index)
        offset = plist[table_addr + index * offset_byte_size, offset_byte_size]
        unpack_int(offset)
      end
    
      def self.unpack_int(s)
        case s.length
        when 1
          s.unpack("C").first
        when 2
          s.unpack("n").first
        when 4
          s.unpack("N").first
        when 8
          i = combine_ints(32, *(s.unpack("NN")))
          (i & 0x80000000_00000000 == 0) ?
            i :
            -(i ^ 0xffffffff_ffffffff) - 1
        when 16
          i = combine_ints(32, *(s.unpack("NNNN")))
          (i & 0x80000000_00000000_00000000_00000000 == 0) ?
            i :
            -(i ^ 0xffffffff_ffffffff_ffffffff_ffffffff) - 1
        else
          raise(ArgumentError, "length must be 1, 2, 4, 8, or 16 bytes")
        end
      end
    
      def self.decode_length(plist, offset)
        if plist[offset] & 0xf == 0xf
          offset += 1
          length = decode_binary_plist_obj(plist, offset, 0)
          offset += min_byte_size(length) + 1
          return length, offset
        else
          return (plist[offset] & 0xf), (offset + 1)
        end
      end
    end
  end
end
