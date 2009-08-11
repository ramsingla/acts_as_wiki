class SpecDatabaseSetup < ActiveRecord::Migration
  def self.up
    
    create_table :sample_actors do |t|
      t.string :name
      t.string :alias
      t.text :biography
      t.text :trivia
    end
    add_index :sample_actors, :name, :unique => true
    
    create_table :users do |t|
      t.string :name
    end
    add_index :users, :name, :unique => true
    
    create_table :wiki_entries do |t|
      t.integer :user_id
      t.integer :wikiable_id
      t.string :wikiable_type
      t.string :column_name
      t.boolean :reverted
      t.text :data
      t.string :summary
      t.text :sources
      t.integer :version
      t.datetime :created_at
    end
    
    add_index :wiki_entries, :user_id, :name => 'wiki_entry_user_idx'
    add_index :wiki_entries, [:wikiable_type, :wikiable_id], :name => 'wiki_entry_wikiable_idx'
    add_index :wiki_entries, [:column_name, :wikiable_type, :wikiable_id, :version], :unique => true, :name => 'wiki_entry_unique_idx'
    
  end
  
  def self.down
    
    drop_table :sample_actors if SampleActor.table_exists?
    drop_table :wiki_entries if WikiEntry.table_exists?
    drop_table :users if User.table_exists?
    
  end
end
