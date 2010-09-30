begin
  require 'zip'
rescue LoadError
  require 'rubygems'
  require 'zip'
end
module IpaReader
  class IpaFile
    attr_accessor :plist
    def initialize(file_path)
      info_plist_file = nil
      Zip::ZipFile.foreach(file_path) { |f| info_plist_file = f if f.name.match(/\/Info.plist/) }
      self.plist = Plist::Binary.decode_binary_plist(info_plist_file.get_input_stream.read)
    end
    
    def version
      plist["CFBundleVersion"]
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
    
    def bundle_identifier
      plist["CFBundleIdentifier"]
    end
    
    def icon_prerendered
      plist["UIPrerenderedIcon"] == true
    end
  end
end