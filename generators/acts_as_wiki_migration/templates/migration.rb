class ActsAsWikiMigration < ActiveRecord::Migration
  def self.up
    
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
    drop_table :wiki_entries
  end
end
