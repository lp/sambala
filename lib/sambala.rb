# This class acts as a Ruby wrapper around the smbclient command line utility,
# allowing access to Samba (SMB, CIFS) shares from Ruby.
# What's special about Sambala's implementation, is that it allows for both both queue
# and interactive commands operations.  While interactive mode is invoked in a blocking manner,
# the queue mode behaves as a non-blocking, multi-threaded, background process.
#
# Sambala works on Unix derivatives operating systems (Linux, BSD, OSX, else),
# as long as the operating system has the smbclient utility installed somewhere in the environment's PATH.
# 
# Sambala supports most, but not all, smbclient features.  I didn't to this point implement
# commands relying on posix server support, because I wanted Sambala to be server agnostic.
# If some commands or interfaces you would like to use is not supported by Sambala,
# email me and I may answer with a quick feature update when feasible.
# 
# I tried to make Sambala as simple as possible, retaining most of the original smbclient command names,
# as instance method names for the Sambala client object.  It behaves as you would expect from an OOP lib:
# You instantiate a new Sambala object and are then allowed to send smbclient commands a instance method to this object.
# The only big difference, is the queue mode, which is activated on a per command/method invocation, with a 'true' flag,
# you add as the last parameter to the method invocation.  When some commands are queued, you can harvest them at a later point
# with the +queue_results+ method, returning an array containing your commands and their respective results.
#
# When in doubt about what each command does, please refer to smbclient man page for help.
# 
# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Sambala

class Sambala
  require 'pty'
  require 'expect'
  require 'rubygems'
  require 'abundance'
  
  require 'sambala_gardener'
  include Gardener
  
  # The +new+ class method initializes Sambala.
  # === Parameters
  # * :domain = the smb server domain, optionnal in most cases
  # * :host = the hostname of the smb server, may be IP or fully qualified domain name
  # * :user = the user name to log into the server
  # * :password = the password to log into the server
  # * :threads = how many parallel operations you want initiated, !!! higher than 4 at you own risk !!!
  # === Example
  #   sam = Sambala.new(  :domain   =>  'NTDOMAIN', 
  #                       :host     =>  'sambaserver', 
  #                       :user     =>  'walrus', 
  #                       :password =>  'eggman', 
  #                       :threads  =>  2 )
  def initialize(options={:domain => '', :host => '', :user => '', :password => '', :threads => 1})
    @options = options; init_gardener
  end
  # The +cd+ instance method takes only one argument, the path to which you wish to change directory
  # Its one of the only implemented command where queue mode is not available, for the simple reason that
  # when queued operations are executed in parallel, one does not control which command will get executed first, 
  # making a queued +cd+ operation very dangerous
  # === Parameters
  # * _path_ = the path to change directory to
  # === Example
  #   sam.cd('aFolder/anOtherFolder/')
  def cd(path)
    execute('cd', path, false)
  end
  
  # The +du+ instance does exactly what _du_ usually does.  See _man du_ for help.
  # === Parameters
  # * _queue_ = the the queue processing mode on for this command invocation when set to true.  Defaults to false when no option given.
  # === Example
  #   puts sam.du   # =>  34923 blocks of size 2097152. 27407 blocks available
  #                       Total number of bytes: 59439077
  def du(queue=false)
    execute('du', '', queue)
  end
  
  # The +del+ instance method delete files on smb shares
  # === Parameters
  # * _path_ = the path of the file to be deleted
  # * _queue_ = the the queue processing mode on for this command invocation when set to true.  Defaults to false when no option given.
  # === Example
  #   sam.del('aFile')
  def del(path,queue=false)
    execute('del', path, queue)
  end
  
  def get(opts={:from => nil, :to => nil, :queue => false})
    opts[:to].nil? ? strng = opts[:from] : strng = opts[:from] + ' ' + opts[:to]
    result = execute('get', strng, opts[:queue])
    return result[0], result[1]
  end
  
  def ls(queue=false)
    mask = nil
    result = execute('ls' ,mask, queue)
    result[1]
  end
  alias dir ls
  
  def mkdir(path,queue=false)
    execute('md' ,path, queue)
  end
  alias md mkdir
  
  def put(opts={:from => nil, :to => nil, :queue => false})
    opts[:to].nil? ? strng = opts[:from] : strng = opts[:from] + ' ' + opts[:to]
    execute('put' ,strng, opts[:queue])
  end
  
  def volume(queue=false)
    execute('volume' ,'', queue)
  end
  
  def queue_results
    crop = @gardener.harvest(:full_crop)
    crop.map! { |result| [ result[:success], result[:seed], result[:message]] }
  end
  
  def close
    return @gardener.close
  end
  
end
