$: << File.expand_path('lib')

require 'test/unit'
require 'doomcaster'

class GoogleSearchTest < Test::Unit::TestCase
  def test_google_search
    google = DoomCaster::Tools::DorkScanner::GoogleSearch
    search = google.new(:query => 'busca')
    assert_equal(search.do_google_search.length <= 100, true)
  end
end
