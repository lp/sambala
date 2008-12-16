class Sambala
  class SmbInitError < StandardError; end
  # The Sambala::Gardener module bings Abundance into Sambala.
  # A bunch of mixins used inside Sambala to access Abundance Non-Blocking Threading.
  # These methods are a higher level abstraction of Abundance methods,
  # serving as reusable general purpose agents inside Sambala.
  # 
  # Author:: lp (mailto:lp@spiralix.org)
  # Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
  # 
  # :title:Sambala::Gardener
  module Gardener
    
    # The +execute+ method splits the execution according to the operation mode: queue or interactive.
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # * _queue_ = the command operation mode
    # === Example
    #   result = execute('cd','dir/otherDir*',false)  # =>  true
    def execute(command,data,queue)
      (queue.is_a? TrueClass) ? exec_queue(command,data) : exec_interactive(command,data)
    end
    
    # The +execute_all+ method does a special command invocation where all smbclient workers running in parallel
    # are all sent the same command.  The method returns one boolean value for all workers success.
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # === Example
    #   result = execute_all('mask','match*')   # =>  true
    def execute_all(command,data)
      sleep 1
      result = @gardener.seed_all("#{command} #{data}")
      bools = result.map { |row| row[:success] }
      bools.uniq.size == 1 ? true : false
    end

    # The +exec_interactive+ method follows +execute+ when queue=false.
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # === Example
    #   result = exec_interactive('put','aFile.txt')    # =>  [false, "aFile.txt does not exist\r\n"]
    def exec_interactive(command,data)
      id = @gardener.seed("#{command} #{data}")
      result = @gardener.harvest(id)
      return result[:success], result[:message]
    end

    # The +exec_queue+ method follows +execute+ when queue=true
    # === Parameters
    # * _command_ = the command as a string
    # * _data_ = the command argument as a string
    # === Example
    #   result = exec_queue('get','aFile.txt')  # => [true,true]
    def exec_queue(command,data)
      @gardener.seed("#{command} #{data}").integer? ? [true,true] : [false,false]
    end
    
    # The +gardener_ok+ method does the +init_gardener+ invocation, degrading the options parameters until
    # it initializes, or raise SmbInitError exception after 4 try.
    def gardener_ok
      init = []
      catch :gardener do
        4.times do |num|
          init_gardener; init = @init_status = @gardener.init_status
          init.map! { |result| result[:success] }
          throw :gardener if init.uniq.size == 1 and init[0] == true
          @gardener.close; @gardener = nil
          @options[:threads] -= 1 unless @options[:threads] == 1; @options[:init_timeout] += 1
        end
        raise SmbInitError.exception("Couldn't set smbclient properly")
      end
    end

    # The +init_gardener+ method initialize a gardener class object
    def init_gardener
      @gardener = Abundance.gardener(:seed_size => 8192, :rows => @options[:threads], :init_timeout => @options[:init_timeout]) do
        PTY.spawn("smbclient //#{@options[:host]}/#{@options[:share]} #{@options[:password]} -W #{@options[:domain]} -U #{@options[:user]}") do |r,w,pid|
          w.sync = true
          $expect_verbose = false
          
          catch :init do
            loop do
              r.expect(/.*\xD\xAsmb:[ \x5C]*\x3E.*/) do |text|
                if text != nil
                  text[0] =~ /.*Server=.*/i ? Abundance.init_status(true,"#{text.inspect}") : Abundance.init_status(false,"#{text.inspect}")
                  throw :init
                end
              end
            end
          end

          Abundance.grow do |seed|
            w.print "#{seed.sprout}\r"
            catch :result do
              loop do
                r.expect(/.*\xD\xAsmb: \w*[\x5C]*\x3E.*/) do |text|
                  if text != nil
                    msg = text[0]
                    
                    msg.gsub!(/smb: \w*\x5C\x3E\s*$/, '')
                    msg.gsub!(/^\s*#{seed.sprout}/, '')
                    msg.lstrip!
                    
                    success = case seed.sprout
                      when /^put/
                        msg['putting'].nil? ? false : true
                      else
                        msg['NT_STATUS'].nil? ? true : false
                      end
                    
                    seed.crop(success, msg)
                    throw :result
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
end