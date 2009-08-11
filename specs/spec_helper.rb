ENV['RAILS_ENV'] ||= 'test'

require 'rubygems'
require 'sqlite3'
require 'activerecord'
require 'active_record/fixtures'  
require 'yaml'  
require 'erb'
require 'spec'

require File.dirname(__FILE__) + '/../init'

[ 'user', 'sample_actor', 'migration' ].each do |i|
  require "#{File.dirname(__FILE__)}/#{i}"
end

tmp_dir = File.dirname(__FILE__) + '/../temp'

ActiveRecord::Base.logger = Logger.new(  tmp_dir  + '/acts_as_wiki_spec.log', 'daily' )

# connect to database.  This will create one if it doesn't exist
MY_DB_NAME = tmp_dir + "/acts_as_wiki.db"
MY_DB = SQLite3::Database.new(MY_DB_NAME)

# get active record set up
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => MY_DB_NAME)

# loading up the database
SpecDatabaseSetup.down
SpecDatabaseSetup.up

# emptying database tables
def clean_database
  [ WikiEntry, SampleActor, User ].each do |model|
    model.delete_all
  end
end

# loading up database table with fixture data
def setup_default_fixtures(files = ['sample_actors' , 'users', 'wiki_entries'])
  Fixtures.reset_cache
  files.each do |f|
    Fixtures.create_fixtures( File.dirname(__FILE__) + '/../fixtures' , File.basename( f , '.*'))
  end
end
