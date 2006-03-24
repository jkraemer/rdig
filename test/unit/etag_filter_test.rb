require 'test_helper'
class UrlFilterTest < Test::Unit::TestCase
  include TestHelper, RDig

  def setup
    @filter = ETagFilter.new
  end

  def test_add
    d0 = OpenStruct.new(:etag => nil)
    assert @filter.apply(d0)
    
    d1 = OpenStruct.new(:etag => 'abc1234')
    assert @filter.apply(d1)
    assert !@filter.apply(d1)

    d2 = OpenStruct.new(:etag => 'abc1235')
    assert @filter.apply(d2)
    assert !@filter.apply(d2)
    assert !@filter.apply(d1)
  end

end
