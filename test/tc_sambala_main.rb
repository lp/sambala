$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'sambala'

class TestHighAPI < Test::Unit::TestCase
  
  def setup
      
  end
  
  def test_main
    check_smbclient_presence
  end
  
  def teardown
    
  end
  
  private
  
  def check_smbclient_presence
    answer = `smbclient --help`
    assert(answer.include?('Usage'))
  end
  
  
end