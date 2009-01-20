$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'sambala'

class TestSambalaMain < Test::Unit::TestCase
  
  def setup
    check_smbclient_presence
    get_samba_param_from_input
    init_sambala
  end
  
  def test_main
    check_ls
  end
  
  def teardown
    close = @samba.close
    assert(close)
  end
  
  private
  
  def check_smbclient_presence
    answer = `smbclient --help`
    assert(answer.include?('Usage'))
  end
  
  def get_samba_param_from_input
    puts "I will need you to input some working Samba connection settings..."
    print "\n"; sleep 1
    print "host name or IP: "
    @host = $stdin.gets.chomp
    print "share name: "
    @share = $stdin.gets.chomp
    print "domain: "
    @domain = $stdin.gets.chomp
    print "user: "
    @user = $stdin.gets.chomp
    print "password: "
    @password = $stdin.gets.chomp
    puts "I will now try to connect to #{@share.to_s} for the purpose of testing sambala..."
    print "\n"
  end
  
  def init_sambala
    begin
      @samba = Sambala.new( :domain => @domain,
                            :host => @host, 
                            :share => @share,
                            :user => @user, 
                            :password => @password, 
                            :threads => 1)
    rescue Sambala::SmbInitError
      raise RuntimeError.exception("Sorry...  I couldn't initialise Sambala")
    end
    puts "Connection to #{@share.to_s} successfull,\nnow proceding with test:"
  end
  
  def check_ls
    result = @samba.ls
    assert_not_nil(result)
  end
  
  
  
end