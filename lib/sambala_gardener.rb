class Sambala
  
  module Gardener
    
    def execute(command,data,queue)
      puts "invoked execute"
      (queue.is_a? TrueClass) ? exec_queue(command,data) : exec_interactive(command,data)
    end

    def exec_interactive(command,data)
      puts "interactive mode: #{command.inspect} !!! #{data.inspect}"
      id = @gardener.seed("#{command} #{data}")
      return message(@gardener.harvest(id))
    end

    def exec_queue(command,data)
      puts "queue mode"
      return @gardener.seed("#{command} #{data}")
    end

    def message(result)
      msg = result[:message][0]
      msg.gsub!(/smb: \x5C\x3E\s*$/, '')
      msg.gsub!(/^\s*#{result[:seed]}/, '')
      msg.lstrip!
      return msg
    end

    def init_gardener
      @gardener = Abundance.gardener(:seed_size => 8192, :rows => @options[:threads], :init_timeout => 3) do
        # puts "@@ yield just before growing..."
        PTY.spawn("smbclient //#{@options[:host]}/#{@options[:share]} #{@options[:password]} -U #{@options[:user]}") do |r,w,pid|
          w.sync = true
          $expect_verbose = false

          r.expect(/.*\xD\xAsmb: \x5C\x3E.*/) do |text|
            # eventually output here into log
          end
          Abundance.grow do |seed|
            neew = seed.sprout
            # puts "??? will go for: #{neew}"
            w.print "#{seed.sprout}\r"
            # sleep 2

            catch :result do
              loop do
                r.expect(/.*\xD\xAsmb: \x5C\x3E.*/) do |text|
                  if text != nil
                    puts "!!! got #{text}"
                    seed.crop(true, text)
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