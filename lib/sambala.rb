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
#                       :password =>  'eggman')
#                       
#   samba.cd('myfolder')   # =>  true
#   samba.put(:from => 'aLocalFile.txt')    # =>  [false, "aLocalFile.txt does not exist\r\n"]
#   samba.close
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
	require 'globalog'
  require 'abundance'
	require File.join( File.dirname( File.expand_path(__FILE__)), 'sambala_helpers')
	include SambalaHelpers
  require File.join( File.dirname( File.expand_path(__FILE__)), 'sambala_gardener')
  include Gardener
  
  # The +new+ class method initializes Sambala.
  # === Parameters
  # * :domain = the smb server domain, optionnal in most cases
  # * :host = the hostname of the smb server, may be IP or fully qualified domain name
  # * :user = the user name to log into the server
  # * :password = the password to log into the server
  # === Example
  #   samba = Sambala.new(  :domain   =>  'NTDOMAIN', 
  #                       :host     =>  'sambaserver',
  #                       :share    =>  'sambashare',
  #                       :user     =>  'walrus', 
  #                       :password =>  'eggman')
  def initialize(options={:domain => '', :host => '', :share => '', :user => '', :password => ''})
    $log_sambala = GlobaLog.logger(STDERR,:warn)
		@recurse = false
		begin
      options[:init_timeout] = 1
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
		execute('cd',clean_path(to))[0]
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
		self.recurse!(false)
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
		self.recurse!(false)
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
    opts[:to].nil? ? strng = opts[:from] + ' ' + opts[:from].split(/[\/|\\]/)[-1]  : strng = opts[:from] + ' ' + opts[:to]
    execute('get', clean_path( strng), opts[:queue])
  end
  
  # The +lcd+ instance method changes the current working directory on the local machine to the directory specified. 
  # === Parameters
  # * _to_ = the path to change directory to
  # === Interactive Returns
  # * _boolean_ = confirms if +cd+ operation completed successfully
  # === Example
  #   samba.lcd('aLocalFolder/anOtherFolder/')   # => true
  def lcd(to='.')
		execute('lcd', to)[0]
  end
  
  # The +lowercase+ method toggles lowercasing of filenames for the get command.
  # Can be usefull when copying files from DOS servers.
  # This method has no queue processing option
  # === Interactive Returns
  # * _boolean_ = confirms if +lowercase+ operation completed successfully
  # === Example
  #   samba.lowercase   # => true      # toggle from files all UPPERCASE to all lowercase
  def lowercase
    execute('lowercase' ,'')[0]
  end
  
  # The method +ls+ or its alias _dir_, list the files and directories matching :mask in the current working directory on the smb server.
  # === Parameters
  # * _mask_ = the mask matching the file to be listed inside the current working directory.
  # === Interactive Returns
  # * _array_ = containing +ls+ command results as Hash of paths as keys and arrays of contained objects ( +LsItem+ ) as values.  Note that recursive operations yields very different results
  # === Example
  #   list = samba.ls  # =>  [{"."=>[#<SambaHelpers::LsItem:0x19c44
	# 																		@type="D", @name="safetyboot",
	# 																		@date="Wed Apr 22 07:53:35 2009",
	# 																		@string="  safetyboot                          D        0  Wed Apr 22 07:53:35 2009",
	# 																		@size="0">]}] 
	# 
  # 	samba.recurse!(true)	# => true
	# 
	# 	samba.ls	# =>	[{"."=>[#<SambaHelpers::LsItem:0x17d54
	# 														@type="D",
	# 														@name="safetyboot",
	# 														@date="Wed Apr 22 07:53:35 2009",
	# 														@string="  safetyboot                          D        0  Wed Apr 22 07:53:35 2009",
	# 														@size="0">]},
	# 									{"\\safetyboot"=>[#<SambaHelpers::LsItem:0x18948
	# 																			@type="D",
	# 																			@name="boot1",
	# 																			@date="Mon Apr 27 09:12:33 2009",
	# 																			@string="  boot1                               D        0  Mon Apr 27 09:12:33 2009",
	# 																			@size="0">,
	# 																		#<SambaHelpers::LsItem:0x17b10
	# 																			@type="D",
	# 																			@name="boot2",
	# 																			@date="Wed Apr 22 07:53:47 2009",
	# 																			@string="  boot2                               D        0  Wed Apr 22 07:53:47 2009",
	# 																			@size="0">]},
	# 									{"\\safetyboot\\boot1"=>[#<SambaHelpers::LsItem:0x174bc
	# 																							@type="A",
	# 																							@name="bootfile.txt",
	# 																							@date="Mon Apr 27 09:12:14 2009",
	# 																							@string="  bootfile.txt                        A        0  Mon Apr 27 09:12:14 2009",
	# 																							@size="4">,
	# 																					 #<SambaHelpers::LsItem:0x17340
	# 																							@type="D",
	# 																							@name="dodidooda",
	# 																							@date="Mon Apr 27 09:12:48 2009",
	# 																							@string="  dodidooda                           D        0  Mon Apr 27 09:12:48 2009",
	# 																							@size="0">],
	# 									 "\\safetyboot\\boot2"=>[#<SambaHelpers::LsItem:0x179a8
	# 																							@type="A",
	# 																							@name="dummmmm.rtf",
	# 																							@date="Wed Apr 22 07:53:41 2009",
	# 																							@string="  dummmmm.rtf                         A        8  Wed Apr 22 07:53:41 2009",
	# 																							@size="8">]},
	# 									{"\\safetyboot\\boot1\\dodidooda"=>[#<SambaHelpers::LsItem:0x9f934
	# 																													@type="A",
	# 																													@name="doodyrt.rtf",
	# 																													@date="Mon Apr 27 09:12:38 2009",
	# 																													@string="  doodyrt.rtf                         A        8  Mon Apr 27 09:12:38 2009",
	# 																													@size="8">]}] 

	def ls(mask='')
    result, string = execute('ls' ,mask, false)
		if result == true
			parse_ls(string,mask)
		else
			Array.new
		end
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
    execute('mask' ,mask)[0]
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

	# The +mkpath+ method creates the needed directory to build the given path
	# This method has no queue processing option
	# === Parameters
  # * _path_ = the directory path to create
	# === Interactive Returns
  # * _boolean_ = confirms if +mkpath+ operation completed successfully
	# === Example
  #   samba.mkpath('aTopFolder/aNewFolder/anOtherNewFolder')  # => true
	def mkpath(path)
		paths = []
		until path == '/' || path == '.'
			paths.unshift path
			path = File.dirname path
		end
		result = String.new
		paths.each do |path|
			result = execute('mkdir' , clean_path(path), false)[0]
			break if result == false
		end
		return result
	end
  
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
	# This methods has 3 possible return values showing the actual "recurse" state:
	# * _true_ = "recurse" is turned on
	# * _false_ = "recurse" is turned off
	# * _nil_ = "recurse" command failed
  # === Example
  #   samba.recurse   # => true
  def recurse
		if execute('recurse' ,'')[0]
			if @recurse == false
				@recurse = true
			else
				@recurse = false
			end
		else
			return nil
		end
  end

	# The +recurse!+ method impose a true or false state to the recurse parameter
	# This method has no queue processing option
	# === Interactive Returns
	# This methods has 3 possible return values showing the actual "recurse" state:
	# * _true_ = "recurse" is turned on
	# * _false_ = "recurse" is turned off
	# * _nil_ = "recurse" command failed
  # === Example
  #   samba.recurse(true)   # => true
	def recurse!(state)
		if state == @recurse
			return @recurse
		else
			return self.recurse
		end
	end
	
	# The recurse? method returns the boolean recurse state
	# === Example
	# 	samba.recurse?				# => false
	def recurse?
		@recurse
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
	
	# The +rmpath+ method deletes the specified directory and all the enclosed content recursively
	def rmpath(path)
		recurse_init = self.recurse?
		self.recurse!(true) if recurse_init != true
		self.ls(path).reverse.each_with_index do |level_hash, index|	
			level_hash.each do |path,item_array|
				base = case index
				when 0
					next
				when 1
					''
				else
					path
				end
				item_array.each do |item|
					
				end
			end
		end
	end
  
  # The +volume+ method returns remote volume information.
  # === Interactive Returns
  # * _string_ = containing +volume+ command results
  # === Example
  #   samba.volume  # => "Volume: |geminishare| serial number 0x6d723053"
  def volume
    execute('volume' ,'', false)[1]
  end
  
	# The +queue_waiting+ method returns the number of waiting task in queue
	# === Example
	# 	samba.queue_waiting		# => 3
	def queue_waiting
		@gardener.growth(:seed)
	end
	
	# The +queue_processing+ method returns an array containing the tasks actually processing
	# === Example
	# 	samba.queue_processing		# => [[1, "put myFile"],[2, "put lib/sambala.rb sambala.rb"]]
	def queue_processing
		results = @gardener.harvest(:sprout)
		results.map { |result| [result[:id], result[:seed]] }
	end
	
	# The +queue_completed+ method returns an array containing the task that have completed
	def queue_completed
		parse_results(@gardener.harvest(:crop))
	end
	
	# The queue_empty? method return true if there are no jobs in queue
	# === Example
	# 	samba.queue_empty?		# false
	def queue_empty?
		@gardener.growth(:empty)
	end
	
	# The queue_done? method return true if all jobs have finished processing
	# === Example
	# 	samba.queue_done? 	# true
	def queue_done?
		@gardener.growth(:finished)
	end
	
  # The +queue_results+ methods wait for all queued items to finish and returns them.
  # === Example 
  #   result = samba.queue_results
  def queue_results
    parse_results(@gardener.harvest(:full_crop))
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
