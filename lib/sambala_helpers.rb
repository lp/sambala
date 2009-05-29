module SambalaHelpers
	
	class LsItem
		attr_reader :string, :name, :type, :size, :date
		def initialize(raw_string)
			@string = raw_string
			if raw_string =~ /\s(\S+)\s+(\w)\s+(\d+)\s+(.*)/
				@name = $1
				@type = $2
				@size = $3
				@date = $4
			else
				@name = @type = @size = @date = nil
			end
		end
	end
	
	def parse_ls(ls_string,mask='')
		base = case mask
		when ''
			'.'
		else
			mask
		end
		if @recurse
			path_tree = [{base => Array.new}]
			now_level = {:level => 0, :top => base}
			base_level = 0
			ls_string.split("\r\n").
				delete_if { |item| item =~ /\.\s.+/ || item =~ /\.\s.+/ || item == '' || item == '*'}.
					each do |item|
						base_level = item.split(/[\\|\/]/).size if base_level == 0
						if item =~ /^[\\|\/]/
							level = item.split(/[\\|\/]/).size - base_level
							path_tree[level] = Hash.new unless path_tree[level]
							path_tree[level][item] = Array.new
							now_level = {:level => level, :top => item}
						else
							path_tree[now_level[:level]][now_level[:top]] << LsItem.new( item)
						end		
					end
		else
			path_tree = [{base => Array.new}]
			ls_string.split("\r\n").
				delete_if { |item| item == "\r\n" || item =~ /blocks\savailable/ || item == '' || item.size == 1 || item =~ /\.\s.+/}.
					each do |item|
						path_tree[0][base] << LsItem.new( item)
					end	
		end
		return path_tree
	end
	
end