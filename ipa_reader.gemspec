# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "ipa_reader"
  s.version = "0.7.1"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nicholas Schlueter"]
  s.date = "2013-09-11"
  s.description = "I am using this gem to get version to build the over the air iPhone Ad Hoc distribution plist file."
  s.email = "schlueter@gmail.com"
  s.executables = ["ipa_reader"]
  s.files = ["History.txt", "README.md", "Rakefile", "bin/ipa_reader", "lib/ipa_reader.rb", "lib/ipa_reader/ipa_file.rb", "lib/ipa_reader/plist_binary.rb", "lib/ipa_reader/png_file.rb", "spec/ipa_reader_spec.rb", "spec/spec_helper.rb", "test/MultiG.ipa", "test/test_ipa_reader.rb", "version.txt"]
  s.homepage = "http://github.com/schlu/Ipa-Reader"
  s.require_paths = ["lib"]
  s.rubyforge_project = "ipa_reader"
  s.rubygems_version = "1.8.25"
  s.summary = "Reads metadata form iPhone Package Archive Files (ipa)."
  s.test_files = ["test/test_ipa_reader.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rubyzip>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<CFPropertyList>, ["= 2.1.1"])
    else
      s.add_dependency(%q<rubyzip>, [">= 1.0.0"])
      s.add_dependency(%q<CFPropertyList>, ["= 2.1.1"])
    end
  else
    s.add_dependency(%q<rubyzip>, [">= 1.0.0"])
    s.add_dependency(%q<CFPropertyList>, ["= 2.1.1"])
  end
end
