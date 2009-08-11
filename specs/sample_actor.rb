class SampleActor < ActiveRecord::Base

  validates_presence_of :name
  validates_uniqueness_of :name
  
end

# 
# SampleActor.acts_as_wiki(:biography)
#