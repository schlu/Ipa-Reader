begin
  require 'zip'
rescue LoadError
  require 'rubygems'
  require 'zip'
end

module DeviceFamily
  IPhone = 1
  IPad = 2
end

module IpaReader
  class IpaFile
    attr_accessor :plist, :file_path, :meta_plist
    def initialize(file_path)
      self.file_path = file_path
      info_plist_file = nil
      regex = /Payload\/[^\/]+.app\/Info.plist/
      cf_plist = CFPropertyList::List.new(:data => self.read_file(regex), :format => CFPropertyList::List::FORMAT_AUTO)
      self.plist = cf_plist.value.to_rb

      meta_data = self.read_file(/iTunesMetadata.plist/)
      if meta_data
        meta_data.chomp! "\u0000"
        self.meta_plist = CFPropertyList::List.new(:data => meta_data, :format => CFPropertyList::List::FORMAT_AUTO).value.to_rb
      else
        self.meta_plist = {}
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
      file = nil
      if plist["CFBundleIconFiles"]
        file = file_name(Regexp.new("#{plist["CFBundleIconFiles"][-1]}$"))
      elsif plist["CFBundleIconFile"]
        file = file_name(Regexp.new("#{plist["CFBundleIconFile"]}$"))
      elsif plist['CFBundleIcons']
        primary_icon = plist["CFBundleIcons"]["CFBundlePrimaryIcon"].value
        icon_files = primary_icon['CFBundleIconFiles'].value
        icon_file = icon_files[-1].value
        file = file_name(Regexp.new("#{icon_file}"))
      else
        file = file_name(Regexp.new("Icon@2x"))
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
      self.meta_plist["itemId"].to_s
    end

    def localized_names
      names = {}
      regex = /Payload\/[^\/]+.app\/(.+)\.lproj\/InfoPlist.strings/
      Zip::ZipFile.foreach(self.file_path) do |f| 
        if f.name.match(regex)
          file = f 
          cf_plist = CFPropertyList::List.new(:data => file.get_input_stream.read, :format => CFPropertyList::List::FORMAT_BINARY).value.to_rb
          names[$1.to_sym] = cf_plist['CFBundleDisplayName']
        end
      end
      names
    end

    def excutable_file
      plist['CFBundleExecutable']
    end

    def genre
      meta_plist['genre']
    end

    def genre_id
      meta_plist['genreId'].to_s
    end

    def artist_id
      meta_plist['artistId'].to_s
    end

    def artist_name
      meta_plist['artistName']
    end

    def release_date
      Date.parse meta_plist['releaseDate']
    end

    def device_family
      plist['UIDeviceFamily']
    end
    
    def read_file(regex)
      file = nil
      Zip::ZipFile.foreach(self.file_path) { |f| file = f if f.name.match(regex) }
      if file
        file.get_input_stream.read
      end
    end

    def file_name(regex)
      file = nil
      Zip::ZipFile.foreach(self.file_path) { |f| file = f if f.name.match(regex) }
      if file
        file.name
      end
    end
  end
end
