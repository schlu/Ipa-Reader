begin
  require 'zip'
rescue LoadError
  require 'rubygems'
  require 'zip'
end

module IpaReader
  class IpaFile
    attr_accessor :plist, :file_path
    def initialize(file_path)
      self.file_path = file_path
      info_plist_file = nil
      regex = /Payload\/[^\/]+.app\/Info.plist/
      Zip::File.foreach(file_path) { |f| info_plist_file = f if f.name.match(regex) }
      cf_plist = CFPropertyList::List.new(:data => self.read_file(regex), :format => CFPropertyList::List::FORMAT_BINARY)
      self.plist = cf_plist.value.to_rb
    end
    
    def version
      plist["CFBundleVersion"]
    end
    
    def short_version
      plist["CFBundleShortVersionString"]
    end
    
    def name
      plist["CFBundleDisplayName"]
    end
    
    def target_os_version
      plist["DTPlatformVersion"].match(/[\d\.]*/)[0]
    end
    
    def minimum_os_version
      plist["MinimumOSVersion"].match(/[\d\.]*/)[0]
    end
    
    def url_schemes
      if plist["CFBundleURLTypes"] && plist["CFBundleURLTypes"][0] && plist["CFBundleURLTypes"][0]["CFBundleURLSchemes"]
        plist["CFBundleURLTypes"][0]["CFBundleURLSchemes"]
      else
        []
      end
    end
    
    def icon_file
      if plist["CFBundleIconFiles"]
        data = read_file(Regexp.new("#{plist["CFBundleIconFiles"][0]}$"))
      elsif plist["CFBundleIconFile"]
        data = read_file(Regexp.new("#{plist["CFBundleIconFile"]}$"))
      end
      if data
        IpaReader::PngFile.normalize_png(data)
      else
        nil
      end
    end
    
    def mobile_provision_file
      read_file(/embedded\.mobileprovision$/)
    end
    
    def bundle_identifier
      plist["CFBundleIdentifier"]
    end
    
    def icon_prerendered
      plist["UIPrerenderedIcon"] == true
    end
    
    def read_file(regex)
      file = nil
      Zip::File.foreach(self.file_path) { |f| file = f if f.name.match(regex) }
      file.get_input_stream.read
    end
  end
end
