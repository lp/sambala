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
# ///////////////////////////////////////////////////////////////////////////////////////
# 
# Example:
# 
#   samba = Sambala.new(  :domain   =>  'NTDOMAIN', 
#                       :host     =>  'sambaserver',
#                       :share    =>  'sambashare',
#                       :user     =>  'walrus', 
#                       :password =>  'eggman', 
#                       :threads  =>  2 )
#                       
#   samba.cd('myfolder')   # =>  true
#   samba.put(:from => 'aLocalFile.txt')    # =>  [false, "aLocalFile.txt does not exist\r\n"]
#   
# 
# For detailed documentation refer to the online ruby-doc:
# http://sambala.rubyforge.org/ruby-doc/
# 
# ///////////////////////////////////////////////////////////////////////////////////////
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
  #   samba = Sambala.new(  :domain   =>  'NTDOMAIN', 
  #                       :host     =>  'sambaserver',
  #                       :share    =>  'sambashare',
  #                       :user     =>  'walrus', 
  #                       :password =>  'eggman', 
  #                       :threads  =>  2 )
  def initialize(options={:domain => '', :host => '', :share => '', :user => '', :password => '', :threads => 1})
    begin
      options[:threads] = 4 if options[:threads] > 4
      options[:init_timeout] = options[:threads]
      @options = options; gardener_ok
    rescue
      @gardener.close unless @gardener.nil? || @gardener.class != 'Gardener'
      raise RuntimeError.exception("Unknown Process Failed!! (#{$!.to_s})")
    end
  end

  # The +cd+ instance method takes only one argument, the path to which you wish to change directory  
  # === Parameters
  # * _to_ = the path to change directory to
  # === Interactive Returns
  # * _boolean_ = confirms if +cd+ operation completed successfully
  # === Example
  #   samba.cd('aFolder/anOtherFolder/')   # =>  true
  def cd(to='.')
		execute_all('cd',clean_path(to))
  end
  
  # The +du+ instance method does exactly what _du_ usually does: estimates file space usage.
  # === Interactive Returns
  # * _string_ = +du+ command results
  # === Example
  #   puts samba.du   # =>  34923 blocks of size 2097152. 27407 blocks available
  #                       Total number of bytes: 59439077
  def du
    execute('du', '', false)[1]
  end
  
  # The +del+ instance method delete files on smb shares
  # === Parameters
  # * _mask_ = the mask matching the file to be deleted inside the current working directory.
  # * _queue_ = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # * _boolean_ = confirms if +del+ operation completed successfully
  # === Example
  #   samba.del('aFile')   # =>  true
  def del(mask, queue=false)
    execute('del', mask, queue)[0]
  end
  alias rm del
  # The exist? instance method is borrowed from Ruby File Class idiome.
  # It is used to test the presence of files or directories on the server
  # === Parameters
  # * _mask_ = the mask matching the file or directory to look for.
  # === Interactive Returns
  # * _boolean_ = confirm the presence of a matching file or directory
  # === Example
  #   samba.exist?('aFile')  # => true
  def exist?(mask)
    execute('ls', mask, false)[0]
  end
  
  # The +get+ instance method copy files from smb shares.
  # As with the smbclient get command, the destination path is optional.
  # === Parameters
  # * :from = the source path, relative path to the current working directory in the smb server
  # * :to = the destination path, absolute or relative path to the current working directory in the local OS
  # * :queue = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # _array_ = [ _booleanSuccess_, _getResultMessage_ ]
  # === Example
  #   samba.get(:from => 'aFile.txt')   # => [true, "getting file \\aFile.txt.rb of size 3877 as test.rb (99.6 kb/s) (average 89.9 kb/s)\r\n"]
  def get(opts={:from => nil, :to => nil, :queue => false})
    opts[:to].nil? ? strng = opts[:from] : strng = clean_path(opts[:from]) + ' ' + opts[:to]
    execute('get', strng, opts[:queue])
  end
  
  # The +lcd+ instance method changes the current working directory on the local machine to the directory specified. 
  # === Parameters
  # * _to_ = the path to change directory to
  # === Interactive Returns
  # * _boolean_ = confirms if +cd+ operation completed successfully
  # === Example
  #   samba.lcd('aLocalFolder/anOtherFolder/')   # => true
  def lcd(to='.')
		execute_all('lcd', to)
  end
  
  # The +lowercase+ method toggles lowercasing of filenames for the get command.
  # Can be usefull when copying files from DOS servers.
  # This method has no queue processing option
  # === Interactive Returns
  # * _boolean_ = confirms if +lowercase+ operation completed successfully
  # === Example
  #   samba.lowercase   # => true      # toggle from files all UPPERCASE to all lowercase
  def lowercase
    execute_all('lowercase' ,'')
  end
  
  # The method +ls+ or its alias _dir_, list the files and directories matching :mask in the current working directory on the smb server.
  # === Parameters
  # * _mask_ = the mask matching the file to be listed inside the current working directory.
  # === Interactive Returns
  # * _string_ = containing +ls+ command results
  # === Example
  #   samba.ls  # =>  genpi.rb                            A       81  Mon Nov 17 22:12:40 2008
  #                     34923 blocks of size 2097152. 27407 blocks available
  def ls(mask='')
    execute('ls' ,mask, false)[1]
  end
  alias dir ls
  
  # The +mask+ method sets a mask to be used during recursive operation of the +mget+ and +mput+ commands.
  # See man page for smbclient to get more on the details of operation
  # This method has no queue processing option
  # === Parameters
  # * _mask_ = the matching filter
  # === Example
  #   samba.mask('filter*')  # => true
  def mask(mask)
    execute_all('mask' ,mask)
  end
  
  # The +mget+ method copy all files matching :mask from the server to the client machine
  # See man page for smbclient to get more on the details of operation
  # === Parameters
  # * _mask_ = the file matching filter
  # * _queue_ = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # _array_ = [ _booleanSuccess_, _mgetResultMessage_ ]
  # === Example
  #   samba.mget('file*')  # => [true, "getting file \\file_new.txt of size 3877 as file_new.txt (99.6 kb/s) (average 89.9 kb/s)\r\n"]
  def mget(mask,queue=false)
    execute('mget' ,mask, queue)
  end
  
  # The method +mkdir+ or its alias _md_, creates a new directory on the server.
  # === Parameters
  # * _path_ = the directory to create
  # * _queue_ = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # * _boolean_ = confirms if +mkdir+ operation completed successfully
  # === Example
  #   samba.mkdir('aFolder/aNewFolder')  # => true
  def mkdir(path, queue=false)
    execute('mkdir' , clean_path(path), queue)[0]
  end
  alias md mkdir
  
  # The +mput+ method copy all files matching :mask in the current working directory on the local machine to the server.
  # See man page for smbclient to get more on the details of operation
  # === Parameters
  # * _mask_ = the file matching filter
  # * _queue_ = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # _array_ = [ _booleanSuccess_, _mputResultMessage_ ]
  # === Example
  #   samba.mput('file*')  # =>  [true, "putting file \\file_new.txt of size 1004 as file_new.txt (65.4 kb/s) (average 65.4 kb/s)\r\n"]
  def mput(mask, queue=false)
    execute('mput' ,mask, queue)
  end
  
  # The +put+ instance method copy files to smb shares.
  # As with the smbclient put command, the destination path is optional.
  # === Parameters
  # * :from = the source path, absolute or relative path to the current working directory in the local OS
  # * :to = the destination path, relative path to the current working directory in the smb server OS
  # * :queue = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # _array_ = [ _booleanSuccess_, _putResultMessage_ ]
  # === Example
  #   samba.put(:from => 'aLocalFile.txt')   # =>  [false, "aLocalFile.txt does not exist\r\n"]

  def put(opts={:from => nil, :to => nil, :queue => false})
    opts[:to].nil? ? strng = opts[:from] : strng = opts[:from] + ' ' + clean_path(opts[:to])
    execute('put' , strng, opts[:queue])
  end
  
  # The +recurse+ method toggles directory recursion
  # This method has no queue processing option
  # === Interactive Returns
  # * _boolean_ = confirms if +mkdir+ operation completed successfully
  # === Example
  #   samba.recurse   # => true
  def recurse
    execute_all('recurse' ,'')
  end

	# The +rmdir+ method deletes the specified directory
	# === Parameters
	# * _path_ = the relative path to the directory to be deleted
  # * _queue_ = sets queue processing mode. Defaults to interactive mode when no option given.
  # === Interactive Returns
  # * _boolean_ = confirms if +rmdir+ operation completed successfully
  # === Example
	# 	samba.rmdir('mydir')		# => true
	def rmdir(path,queue=false)
		execute('rmdir' , clean_path(path), queue)[0]
	end
  
  # The +volume+ method returns remote volume information.
  # === Interactive Returns
  # * _string_ = containing +volume+ command results
  # === Example
  #   samba.volume  # => "Volume: |geminishare| serial number 0x6d723053"
  def volume
    execute('volume' ,'', false)[1]
  end

	# The +local+ methods allow shell command execution on the local machine.
	# === Parameters
	# * _command_ = the shell comand to be executed locally
	# === Interactive Returns
	# * _string_ = the normal return message of the command
	# === Example
	# 	samba.local('mkdir mydir')
	def local(command)
		execute('!', command, false)[1]
	end
  
  # The +queue_results+ methods wait for all queued items to finish and returns them.
  # === Example 
  #   result = samba.queue_results
  def queue_results
    crop = @gardener.harvest(:full_crop)
    crop.map! { |result| [ result[:success], result[:seed], result[:message] ]  }
  end
  
  # The +progress+ method returns a progress ratio indicator from 0.00 to 1.00
  # === Example
  #   progress = samba.progress   # => 0.75
  def progress
    @gardener.growth(:progress)
  end
  
  # The +close+ method safely end the smbclient session
  # === Example
  #   samba.close
  def close
    result = @gardener.close
    result.values.map { |queue| queue.empty? }.uniq.size == 1 ? true : false
  end
  
end
