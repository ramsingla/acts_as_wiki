namespace :acts_as_wiki  do

  desc 'Execute plugin specs'
  task :specs do
    files = [ 'wiki_entry', 'wiki_column_proxy', 'acts_as_wiki_spec' 
      ].map do |f|
      "#{File.dirname(__FILE__)}/../specs/#{f}_spec.rb"
    end.join( ' ' )

    Kernel.system( "spec #{files}" )
  end

end