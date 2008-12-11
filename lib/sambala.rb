class Sambala
  require 'pty'
  require 'expect'
  require 'rubygems'
  require 'abundance'
  
  require 'sambala_gardener'
  include Gardener
  
  def initialize(options={:host => '', :user => '', :password => '', :threads => 1})
    @options = options; init_gardener
  end
  
  def cd(path)
    execute('cd', path, false)
  end
  
  def du(queue=false)
    execute('du', '', queue)
  end
  
  def del(path,queue=false)
    execute('del', path, queue)
  end
  
  def get(opts={:from => nil, :to => nil, :queue => false})
    opts[:to].nil? ? strng = opts[:from] : strng = opts[:from] + ' ' + opts[:to]
    execute('get', strng, opts[:queue])
  end
  
  def ls(queue=false)
    # puts "invoked ls"
    mask = nil
    execute('ls' ,mask, queue)
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
    crop.map! do |c|
      c.delete(:id); c.delete(:success); c
    end
    return crop.to_a
  end
  
  def close
    return @gardener.close
  end
  
end
