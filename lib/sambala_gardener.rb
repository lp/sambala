# Author:: lp (mailto:lp@spiralix.org)
# Copyright:: 2008 Louis-Philippe Perron - Released under the terms of the MIT license
# 
# :title:Sambala::Gardener

class Sambala
  
  module Gardener
    
    def execute(command,data,queue)
      (queue.is_a? TrueClass) ? exec_queue(command,data) : exec_interactive(command,data)
    end

    def exec_interactive(command,data)
      id = @gardener.seed("#{command} #{data}")
      result = @gardener.harvest(id)
      return result[:success], result[:message]
    end

    def exec_queue(command,data)
      return @gardener.seed("#{command} #{data}")
    end

    def init_gardener
      @gardener = Abundance.gardener(:seed_size => 8192, :rows => @options[:threads], :init_timeout => 3) do
        PTY.spawn("smbclient //#{@options[:host]}/#{@options[:share]} #{@options[:password]} -U #{@options[:user]}") do |r,w,pid|
          w.sync = true
          $expect_verbose = false
          
          catch :init do
            loop do
              r.expect(/.*\xD\xAsmb:[ \x5C]*\x3E.*/) do |text|
                if text != nil
                  Abundance.init_status(true,"#{text.inspect}")
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