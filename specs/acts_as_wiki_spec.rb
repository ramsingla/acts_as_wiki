require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def ar_class(name)
  eval %Q(class #{name} < ActiveRecord::Base; end)
  name.constantize
end

describe ActiveRecord::Acts::Wiki do
  
  describe 'on first use' do
    
    it 'should include class variable' do
      klass = ar_class('AAWC1')
      begin
        klass.acts_as_wiki_column_names
      rescue StandardError => err
        err.class.should == NoMethodError
      end
      klass.acts_as_wiki
      klass.acts_as_wiki_column_names.should be_empty
    end
    
    it 'should take a column_name' do
      klass = ar_class('AAWC2')
      klass.acts_as_wiki :biography
      klass.acts_as_wiki_column_names.should be_include(:biography)
    end
    
    it 'should take more than one column_name' do
      klass = ar_class('AAWC3')
      klass.acts_as_wiki :biography, :trivia
      klass.acts_as_wiki_column_names.should be_include(:biography)
      klass.acts_as_wiki_column_names.should be_include(:trivia)
    end
    
    it 'should include a2w_active' do
      klass = ar_class('AAWC4')
      klass.acts_as_wiki
      klass.should be_a2w_active
    end
    
  end
  
  
  describe 'on multiple use' do
    
    before do
      @klass = ar_class('AAWMC')
      @klass.acts_as_wiki :biography
    end
    
    it 'should not reset acts_as_wiki_column_names' do
      @klass.acts_as_wiki_column_names.should be_include(:biography)
      @klass.acts_as_wiki :biography
      @klass.acts_as_wiki_column_names.should be_include(:biography)
    end
    
    it 'should not include column more than once' do
      @klass.acts_as_wiki_column_names.should be_include(:biography)
      @klass.acts_as_wiki :biography
      @klass.acts_as_wiki :trivia
      @klass.acts_as_wiki :trivia
      @klass.acts_as_wiki :biography
      @klass.acts_as_wiki :trivia
      @klass.acts_as_wiki_column_names.uniq.should == @klass.acts_as_wiki_column_names
    end
    
    it 'should not differ b/w symbol & string when specifying a column name' do
      @klass.acts_as_wiki_column_names.should be_include(:biography)
      @klass.acts_as_wiki 'biography'
      @klass.acts_as_wiki_column_names.should be_include(:biography)
      @klass.acts_as_wiki_column_names.should_not be_include('biography')
    end
    
  end
  
  describe 'wiki proxy column' do
    
    before do
      SampleActor.acts_as_wiki :biography
      @actor = SampleActor.new
    end
    
    it 'should behave like accessor methods' do
      @actor.biography.should be_nil
      @actor.biography = 'bio'
      @actor.biography.should == 'bio'
      SampleActor.new(:biography => 'bio').biography.should == 'bio'
    end
    
    it 'should add :save method to update the proxy column' do
      @actor.biography.respond_to?(:save).should be_true
    end
    
    it 'should add :edit method to edit proxy column' do
       @actor.biography.respond_to?(:edit).should be_true
    end
    
    it 'should add :rollback method to rollback' do
      @actor.biography.respond_to?(:rollback).should be_true
    end
    
    it 'should add :data method to get old/current versions' do
      @actor.biography.respond_to?(:data).should be_true
    end
    
    it 'should add :summary method to get old/current summary info' do
      @actor.biography.respond_to?(:summary).should be_true
    end
    
    it 'should add :user_id method to get old/current author_id info' do
      @actor.biography.respond_to?(:user_id).should be_true
    end
    
    it 'should add :user method to get old/current author object' do
      @actor.biography.respond_to?(:user).should be_true
    end
    
    it 'should add :rollbacked? method to get old/current rollback status' do
      @actor.biography.respond_to?(:rollbacked?).should be_true
    end
    
    it 'should add :find method to find version/version collection' do
      @actor.biography.respond_to?(:find).should be_true
    end
    
    it 'should add :version method to get current version info' do
      @actor.biography.respond_to?(:version).should be_true
    end
    
    it 'should add :diff method to compare two versions' do
      @actor.biography.respond_to?(:diff).should be_true
    end
    
    it 'should add :updated_at method to get creation time of curr version' do
      @actor.biography.respond_to?(:updated_at).should be_true
    end
    
  end
  
  describe 'owner.save' do
    
    before do
      setup_default_fixtures
      SampleActor.acts_as_wiki :biography, :trivia
      @actor = SampleActor.find(1)
    end
    
    after do
      clean_database
    end
    
    it 'should save properly without change to wiki columns' do
      bv = @actor.biography.version
      tv = @actor.trivia.version
      @actor.name.upcase!
      @actor.save.should be_true
      @actor.biography.version.should == bv
      @actor.trivia.version.should == tv
    end
  
    it 'should not save object if wiki column are not valid' do
      @actor.name.upcase!
      @actor.biography += 'Added Few More Characters'
      @actor.save.should be_false
      @actor.errors.full_messages.should be_include('Biography wiki_entry is not valid') # missing attribute user_id is required
      @actor.trivia = 'Altered the old trivia'
      @actor.save.should be_false
      @actor.errors.full_messages.should be_include('Trivia wiki_entry is not valid')
    end
    
    it 'should save object and wiki columns if valid (case single wiki column update)' do
      bv = @actor.biography.version
      @actor.name.upcase!
      @actor.biography += 'Added Few More Characters'
      @actor.biography.edit(:user_id => 3, :summary => 'adding up')
      @actor.save.should be_true
      @actor.biography.version.should == bv+1
    end
    
    it 'should save object and wiki columns if valid (case multiple wiki column update)' do
      bv = @actor.biography.version
      tv = @actor.trivia.version
      @actor.name.upcase!
      @actor.biography += ' Added Few More Characters'
      @actor.biography.edit(:user_id => 3, :summary => 'adding up')
      @actor.trivia = 'New Trivia'
      @actor.trivia.edit(:user_id => 1, :summary => 'hello')
      @actor.save.should be_true
      @actor.biography.version.should == bv+1
      @actor.trivia.version.should == tv+1
    end
    
    it 'should save new owner with nil wiki column' do
      actor = SampleActor.new(:name => 'Gemma Larsen')
      actor.save.should be_true
    end
    
    it 'should save new owner with valid wiki column' do
      actor = SampleActor.new(:name => 'Gemma Larsen', :biography => 'dummy')
      actor.biography.edit(:user_id => 3)
      actor.save.should be_true
      actor.biography.version.should == 1
    end
    
    it 'should save new owner with multiple valid wiki columns' do
      actor = SampleActor.new(:name => 'Gemma Larsen', :biography => 'dummy')
      actor.biography.edit(:user_id => 3)
      actor.trivia = {:data => 'hello trivia', :user_id => 3, :summary => 'foo'}
      actor.save.should be_true
      actor.biography.version.should == 1
    end
    
  end
  
end