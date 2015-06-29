
require_relative '../lib/common.rb'
require 'test/unit'

class CommonTest < Test::Unit::TestCase
  def test_common
    default_langs = ['any', 'cfm', 'asp', 'php']
    assert_equal(default_langs, get_langs('../lists'))
  end
end
