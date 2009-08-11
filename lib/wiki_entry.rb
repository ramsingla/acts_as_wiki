require 'diff/lcs'

class WikiEntry < ActiveRecord::Base
  
  validates_presence_of :user_id, :wikiable_type, :column_name
  validates_presence_of :version, :if => Proc.new{ |r| r.reverted? }
  validates_presence_of :data, :if => Proc.new { |r| !r.reverted? }
  validate :validate_foreign_key_constraints_for_user
  
  before_save :validate_foreign_key_constraints_for_wikiable_type
  before_save :revert_to_previous_version, :if => Proc.new{ |r| r.reverted? }
  before_save :auto_set_version
  
  belongs_to :wikiable, :polymorphic => true
  belongs_to :user
  
  def to_s
    data
  end
  
  def current_version
    self.class.current_version(attributes)
  end
  
  class << self
    
    # attribute summary should be nil to be autoset
    def revert_to(version, attributes={})
      attributes = attributes.symbolize_keys
      create(attributes.merge!(:version => version, :reverted => true))
    end
    
    # default version is current_version
    def version_entry(attributes={}, extract=true)
      attributes = attributes.symbolize_keys
      conditions = extract ? extract_conditions(attributes) : attributes
      conditions[:version] ||= (attributes[:version] ||
        current_version(conditions, false))
      find(:first, :conditions => conditions) 
    end
    
    def current_version(attributes={}, extract=true)
      maximum(:version, :conditions => ( extract ? 
        extract_conditions(attributes) : attributes )).to_i
    end
    
    # Change the test case for this
    def history(first_or_all = :all, attributes={}, options={})
      options.symbolize_keys!
      options[:order] ||= 'version DESC'
      with_scope(:find => {:conditions => extract_conditions(attributes)}) do
        find(first_or_all, options)
      end
    end
  
    def diff(version_a, version_b, attributes={})
      conditions = extract_conditions(attributes)
      conditions[:version] = version_a
      wiki_entry_a = version_entry(conditions, false)
      conditions[:version] = version_b
      wiki_entry_b = version_entry(conditions, false)
      data_a = wiki_entry_a.data.to_s.split(/\r\n?|\n/)
      data_b = wiki_entry_b.data.to_s.split(/\r\n?|\n/)
      Diff::LCS.sdiff(data_a, data_b)        
    end
    
    protected
    
    def extract_conditions(attributes)
      attributes = attributes.symbolize_keys
      conditions = Hash.new
      [:column_name, :wikiable_type, :wikiable_id].each do |attribute|
        attr_val = attributes[attribute]
        raise(ArgumentError, 
          "attribute :#{attribute} required") unless attr_val
        conditions[attribute] = attr_val
      end
      return conditions
    end
    
  end
  
  protected
  
  def validate_foreign_key_constraints_for_user
    errors.add('user_id', 
      'voilates foreign key constraint') unless User.exists?(user_id)
  end
  
  def validate_foreign_key_constraints_for_wikiable_type
    if wikiable_type
      wclass = wikiable_type.constantize
      errors.add('wikiable_id', 
        'voilates foreign key constraint') unless wclass.exists?(wikiable_id)
    end
    return errors.empty? 
  end
  
  def revert_to_previous_version
    prev_wiki_entry = self.class.version_entry(attributes)
    unless prev_wiki_entry
      errors.add_to_base(
        "Wiki entry corresponding to version #{version} not found.") 
      return false
    end
    self.data = prev_wiki_entry.data
    self.summary ||= "Reverted to version #{version}"
    return true
  end
  
  def auto_set_version
    self.version = self.current_version + 1
    return true
  end

end
