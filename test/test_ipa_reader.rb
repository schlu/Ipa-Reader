require File.dirname(__FILE__) + '/../lib/ipa_reader'
require 'test/unit'

class IpaReaderTest < Test::Unit::TestCase
  def setup
    @ipa_file = IpaReader::IpaFile.new(File.dirname(__FILE__) + '/MultiG.ipa')
  end
  
  def test_parse
    assert(@ipa_file.plist.keys.count > 0)
  end
  
  def test_version
    assert_equal(@ipa_file.version, "1.2.2.4")
  end
  
  def test_name
    assert_equal(@ipa_file.name, "MultiG")
  end
  
  def test_target_os_version
    assert_equal(@ipa_file.target_os_version, "4.1")
  end
  
  def test_minimum_os_version
    assert_equal(@ipa_file.minimum_os_version, "3.1")
  end
  
  def test_url_schemes
    assert_equal(@ipa_file.url_schemes, [])
  end
  
  def test_bundle_identifier
    assert_equal("com.dcrails.multig", @ipa_file.bundle_identifier)
  end

  def test_icon_prerendered
    assert_equal(false, @ipa_file.icon_prerendered)
  end
  
  
end