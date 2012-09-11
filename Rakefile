
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name  'ipa_reader'
  authors  'Nicholas Schlueter'
  summary 'Reads metadata form iPhone Package Archive Files (ipa).'
  description 'I am using this gem to get version to build the over the air iPhone Ad Hoc distribution plist file.'
  email    'schlueter@gmail.com'
  url      'http://github.com/schlu/Ipa-Reader'
  depend_on "zip", "2.0.2"
  depend_on "CFPropertyList", "2.1.1"
}

