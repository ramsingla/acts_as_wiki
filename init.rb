[ 'wiki_entry', 'wiki_column_proxy', 'acts_as_wiki'].each do |i|
  require "#{File.dirname(__FILE__)}/lib/#{i}"
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::Wiki
