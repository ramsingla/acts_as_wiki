module ActiveRecord #:nodoc:
  module Acts #:nodoc:
    # Specify this act if you want to store a particular field of a model as a
    # versioned wiki. This assumes there is a global wiki table (wiki_entries) 
    # which can be created through migration generation task and then doing a
    # rake db:migrate.
    #
    # The class for the wiki table is WikiEntry and is loaded when plugin is
    # loaded. 
    #
    #   class Actor < ActiveRecord::Base
    #     acts_as_wiki :biography
    #   end
    #
    # Example:
    #
    #  Current Version
    #
    #  actor.biography => curent biography of actor
    #  actor.biography.version => 6
    #  actor.biography.summary => summary for the current biography
    #  actor.biography.sources => sources for the current biography
    #  actor.biography.user_id => author id for the current biography
    #  actor.biography.user => author for the current biography
    #  actor.biography.rollbacked? => the current biography is rollbacked ?
    #  
    #  Old Versions
    #
    #  actor.biography.data(4) => biography from version 4
    #  actor.biography.summary(4) => summary from version 4
    #  actor.biography.sources(4) => sources from version 4
    #  actor.biography.user(4) => author from version 4
    #  actor.biography.user_id(4) => author_id form version 4
    #  actor.biography.rollbacked?(4) => rollback status for version 4
    #
    #  Finder (Return WikiEntry Obj or Collection of WikiEntry Objs)
    #
    #  actor.biography.find(:first) => Returns WikiEntry Obj for current version
    #  actor.biography.find(:all)   => decreasing in version all revisions
    #  actor.biography.find(:first, :conditions => {:version => 2})
    #  actor.biography.find(:all, :order => 'version ASC') => reverse order
    #
    #  Saving Biography with actor.save
    #  (changing one or more actor attributes and saving the actor record in 
    #   one go)
    #
    #  Solution 1
    #  actor.biography = 'New biography'
    #  actor.biography.edit(:user_id => 1, :summary => 'new',
    #    :sources=>'hello')
    #  actor.save
    #
    #  Solution 2
    #  actor.biography = {:data => 'New biography', :user_id => 1, 
    #    :summary => 'new', :sources => 'hello'}
    #  actor.save
    #
    #  Solution 3
    #  actor.biography.edit(:data => 'New biography', :user_id => 1, 
    #    :summary => 'new', :sources => 'hello')
    #  actor.save
    #
    #  Updating Only Biography Field with actor.biography.save
    #  (updating only biography field of the actor)
    #
    #  Solution 1
    #  actor.biography = 'New biography'
    #  actor.biography.edit(:user_id => 1, :summary => 'new',
    #    :sources=>'hello')
    #  actor.biography.save
    #
    #  Solution 2
    #  actor.biography = {:data => 'New biography', :user_id => 1, 
    #    :summary => 'new', :sources => 'hello'}
    #  actor.biography.save
    #
    #  Solution 3
    #  actor.biography.edit(:data => 'New biography', :user_id => 1, 
    #    :summary => 'new', :sources => 'hello')
    #  actor.biography.save
    #
    #  Rollback to Previous Versions
    #  (rollback always create a new record with next version but old data)
    #
    #  actor.biography.rollback(4, user_id) # rollback to version 4 with user_id
    #  actor.biography.rollback(4, user_id, "rb v4") # with summary also
    #  actor.biography.rollback(4, user) # rollback with user instead of user_id
    #  actor.biography.rollabck(4, user, "rb v4") # with summary and user
    #
    #  while rollbacking if summary is not provided it is autoset
    #
    #  actor.biography.diff(3, 4)  # gives array of changes b/w version 3 & 4
    #    
    module Wiki
      
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        
        def acts_as_wiki(*column_names)
          logger.error(%Q(TASK PENDING: 
  ruby script/generate acts_as_wiki_migration
  rake db:migrate)) unless WikiEntry.table_exists?
          
          #called for the first time
          unless self.a2w_active?
            cattr_accessor :acts_as_wiki_column_names
            self.acts_as_wiki_column_names = []
            include ActiveRecord::Acts::Wiki::Callbacks
            class_eval do 
              before_save :a2w_validate_wiki_entries
              after_save  :a2w_save_wiki_entries
              after_destroy :a2w_destroy_wiki_entries
              protected(:a2w_validate_wiki_entries,
                :a2w_save_wiki_entries)
            end
          end
          column_names.collect!(&:to_sym)
          column_names -= self.acts_as_wiki_column_names
          column_names.each{ |c| a2w_overwrite_column_accesor(c) }
          self.acts_as_wiki_column_names += column_names
        end
        
        def a2w_active?
          self.included_modules.include?(ActiveRecord::Acts::Wiki::Callbacks)
        end
        
        protected
        
        def a2w_overwrite_column_accesor(c)
          class_eval %Q(
            def #{c}
              self.a2w_#{c} ||= WikiColumnProxy.new(self, :#{c})
            end
            
            def #{c}=(val)
              attrs = val.is_a?(Hash) ?  val : { :data => val }
              #{c}.edit(attrs)
            end
            
            protected
            attr_accessor :a2w_#{c}
          )
        end
        
      end
      
      
      module Callbacks
        
        def a2w_validate_wiki_entries
          self.class.acts_as_wiki_column_names.inject(true) do |v, c|
            pc = self.send(c)
            if self.new_record?
              vv = pc.proxy_target.blank? ? true : pc.valid?
            else 
              vv = a2w_changed?(pc) ? pc.valid? : true
            end
            self.errors.add(c, "wiki_entry is not valid") unless vv
            v = v && vv
          end
        end
        
        # Destroy method can be improvised
        def a2w_destroy_wiki_entries
          self.class.acts_as_wiki_column_names.each do |c|
            self.send(c).find(:all).each{ |x| x.destroy }
          end
        end
        
        def a2w_save_wiki_entries
          self.class.acts_as_wiki_column_names.each do |c| 
            pc = self.send(c).reload
            pc.save(false) if a2w_changed?(pc)
          end
        end
        
        def a2w_changed?(pc)
          pc.blank? && pc.data.blank? ? false : pc != pc.data
        end
      end
      
    end
  end
end
