begin
  require 'zip'
rescue LoadError
  require 'rubygems'
  require 'zip'
end

module IpaReader
  class IpaFile
    attr_accessor :plist, :file_path, :meta_plist
    def initialize(file_path)
      self.file_path = file_path
      info_plist_file = nil
      regex = /Payload\/[^\/]+.app\/Info.plist/
      cf_plist = CFPropertyList::List.new(:data => self.read_file(regex), :format => CFPropertyList::List::FORMAT_BINARY)
      self.plist = cf_plist.value.to_rb

      meta_data = self.read_file(/iTunesMetadata.plist/)
      if meta_data
        self.meta_plist = CFPropertyList::List.new(:data => meta_data).value.to_rb
      end
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
        plist["CFBundleURLTypes"][0]["CFBundleURLSchemes"].value.map { |schema| schema.value }
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

    def app_id
      if meta_plist
        meta_plist["itemId"].to_s
      end
    end

    def localized_names
      names = {}
      regex = /Payload\/[^\/]+.app\/(.+)\.lproj\/InfoPlist.strings/
      Zip::ZipFile.foreach(self.file_path) do |f| 
        if f.name.match(regex)
          file = f 
          cf_plist = CFPropertyList::List.new(:data => file.get_input_stream.read, :format => CFPropertyList::List::FORMAT_BINARY).value.to_rb
          names[$1] = cf_plist['CFBundleDisplayName']
        end
      end
      names
    end
    
    def read_file(regex)
      file = nil
      Zip::ZipFile.foreach(self.file_path) { |f| file = f if f.name.match(regex) }
      if file
        file.get_input_stream.read
      end
    end
  end
end
