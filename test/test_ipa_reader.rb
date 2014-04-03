require File.dirname(__FILE__) + '/../lib/ipa_reader'
require 'test/unit'

class IpaReaderTest < Test::Unit::TestCase
  def setup
    @ipa_file = IpaReader::IpaFile.new(File.dirname(__FILE__) + '/Find iPhone.ipa')
  end
  
  def test_parse
    assert(@ipa_file.plist.keys.count > 0)
  end
  
  def test_version
    assert_equal(@ipa_file.version, "376")
  end
  
  def test_short_version
    # asserting nil because the test file doesn't have this key
    assert_equal(@ipa_file.short_version, "3.0")
  end
  
  def test_name
    assert_equal(@ipa_file.name, "FindMyiPhone")
  end
  
  def test_target_os_version
    assert_equal(@ipa_file.target_os_version, "7.0")
  end
  
  def test_minimum_os_version
    assert_equal(@ipa_file.minimum_os_version, "7.0")
  end
  
  def test_url_schemes
    assert_equal(@ipa_file.url_schemes, ['fmip1'])
  end
  
  def test_bundle_identifier
    assert_equal("com.apple.mobileme.fmip1", @ipa_file.bundle_identifier)
  end

  def test_icon_prerendered
    assert_equal(true, @ipa_file.icon_prerendered)
  end
  
  def test_app_id
    assert_equal('376101648', @ipa_file.app_id)
  end

  def test_localized_names
    assert_equal({"ar"=>"عثور iPhone",
                   "ca"=>"Buscar",
                   "cs"=>"Najít iPhone",
                   "da"=>"Find iPhone",
                   "de"=>"Mein iPhone",
                   "el"=>"Εύρεση",
                   "en"=>"Find iPhone",
                   "en_GB"=>"Find iPhone",
                   "es"=>"Buscar",
                   "fi"=>"Etsi iPhone",
                   "fr"=>"Localiser",
                   "he"=>"מצא iPhone",
                   "hr"=>"Nađi iPhone",
                   "hu"=>"Keresés",
                   "id"=>"Cari iPhone",
                   "it"=>"Trova iPhone",
                   "ja"=>"Find iPhone",
                   "ko"=>"iPhone 찾기",
                   "ms"=>"Cari iPhone",
                   "nl"=>"Zoek iPhone",
                   "no"=>"Finn iPhone",
                   "pl"=>"Znajdź",
                   "pt"=>"Buscar",
                   "pt_PT"=>"Encontrar",
                   "ro"=>"Găsire iPhone",
                   "ru"=>"Найти iPhone",
                   "sk"=>"Nájsť iPhone",
                   "sv"=>"Hitta iPhone",
                   "th"=>"ค้นหา iPhone",
                   "tr"=>"iPhone'u Bul",
                   "uk"=>"Де iPhone",
                   "vi"=>"Tìm iPhone",
                   "zh_CN"=>"查找 iPhone",
                   "zh_TW"=>"尋找 iPhone"}, @ipa_file.localized_names)
  end
  
end