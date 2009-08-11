require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe WikiEntry do
  
  describe 'when performing validations' do
  
    before do
      @wiki_entry = WikiEntry.new(
        :column_name => 'biography',
        :wikiable_type => 'SampleActor',
        :wikiable_id => 99,
        :data => 'hello',
        :user_id =>  999
      )
      User.should_receive(:exists?).and_return(true)
    end
    
    it 'should be valid with valid parameters' do
      @wiki_entry.should be_valid
    end
    
    it 'should not be valid without a user' do
      @wiki_entry.user_id = nil
      @wiki_entry.should_not be_valid
    end
    
    it 'should be valid with nil wikiable_id' do 
      @wiki_entry.wikiable_id = nil
      # you can associate wiki entry with new wikiable record
      @wiki_entry.should be_valid
    end
    
    it 'should not be valid without nil wikiable_type' do
      @wiki_entry.wikiable_type = nil
      @wiki_entry.should_not be_valid
    end
    
    it 'should not be valid without column_name' do
      @wiki_entry.column_name = nil
      @wiki_entry.should_not be_valid
    end
    
    it 'should not be valid without version if want to revert' do
      @wiki_entry.reverted = true
      @wiki_entry.version = nil
      @wiki_entry.should_not be_valid
    end
    
    it 'should not be valid with version if want to revert' do
      @wiki_entry.reverted = true
      @wiki_entry.version = 1
      @wiki_entry.should be_valid
    end
    
    it 'should not be valid without data if want to edit' do
      @wiki_entry.data = nil
      @wiki_entry.reverted = false
      @wiki_entry.should_not be_valid
    end
    
    it 'should be valid without data unless we want to revert' do
      @wiki_entry.data = nil
      @wiki_entry.reverted = true
      @wiki_entry.version = 3
      @wiki_entry.should be_valid
    end
  
  end
  
  describe 'when creating records' do
    
    before do
      @real_user = User.create(:name => 'Acts As Wiki User')
      @real_actor = SampleActor.create(:name => 'Acts As Wiki Actor')
      @wiki_entry = WikiEntry.new(
        :column_name => 'biography',
        :wikiable_type => 'SampleActor',
        :wikiable_id => @real_actor.id+100,
        :data => 'hello',
        :user_id => @real_user.id+100
      )
    end
    
    after do
      clean_database
    end
    
    it  'should not create if user foreign key constraint fail' do
      @wiki_entry.wikiable = @real_actor
      @wiki_entry.save.should be_false
    end
    
    it 'should not create if wikiable foreign key constraint fail' do
      @wiki_entry.user = @real_user
      @wiki_entry.save.should be_false
    end
    
    it 'should not create if version entry is not found on revert' do
      @wiki_entry.wikiable = @real_actor
      @wiki_entry.user = @real_user
      @wiki_entry.reverted = true
      @wiki_entry.version  = 9999
      @wiki_entry.save.should be_false
    end
    
    it 'should autoset version entry on successful create' do
      @wiki_entry.wikiable = @real_actor
      @wiki_entry.user = @real_user
      attributes = @wiki_entry.attributes
      attributes.delete('id')
      @wiki_entry.save.should be_true
      @wiki_entry.version.should == 1
      new_wiki_entry = WikiEntry.new(attributes.merge!('data' => 'hello world'))
      new_wiki_entry.save.should be_true
      new_wiki_entry.version.should == 2
    end
    
    it 'should autoset version entry on successful revert' do
      @wiki_entry.wikiable = @real_actor
      @wiki_entry.user = @real_user
      attributes = @wiki_entry.attributes
      attributes.delete('id')
      @wiki_entry.save #version = 1
      3.times do |i|
        we = WikiEntry.create(attributes.merge!('data' => i))
      end #version = 4
      reverted_wiki_entry = WikiEntry.new(
        attributes.merge!( :reverted => true, :version => 1))
      reverted_wiki_entry.save.should be_true
      reverted_wiki_entry.version.should == 5
      reverted_wiki_entry.data.should == @wiki_entry.data
      reverted_wiki_entry.should be_reverted
    end
    
  end
  
  describe 'public class_methods interface' do
    
    before do
      setup_default_fixtures
      @attributes = {:wikiable_id => 1,
        :wikiable_type => 'SampleActor', 
        :column_name => 'biography',
        :user_id => 1
      }
    end
    
    after do
      clean_database
    end
    
    it 'should require wikiable_id as required attribute' do
      @attributes.delete(:wikiable_id)
      begin
        WikiEntry.send(:extract_conditions, @attributes)
      rescue Exception => err
        err.class.should == ArgumentError
      else
        raise 'excpetion not raised as expected'
      end
    end
    
    it 'should require wikiable_type as required attribute' do
      @attributes.delete(:wikiable_type)
      begin
        WikiEntry.send(:extract_conditions, @attributes)
      rescue Exception => err
        err.class.should == ArgumentError
      else
        raise 'excpetion not raised as expected'
      end
    end
    
    it 'should require column_name as required attribute' do
      @attributes.delete(:column_name)
      begin
        WikiEntry.send(:extract_conditions, @attributes)
      rescue Exception => err
        err.class.should == ArgumentError
      else
        raise 'excpetion not raised as expected'
      end
    end
    
    it 'should provide history method' do
      arr = WikiEntry.history(:all, @attributes)
      arr.size.should == 5
      arr.first.version.should == 5
      arr.last.version.should == 1
    end
    
    it 'should provide current_version method' do
      WikiEntry.current_version(@attributes).should == 5
    end
        
    it 'should provide version_entry method' do
      wiki = WikiEntry.version_entry(@attributes.merge(:version => 3))
      wiki.version.should == 3
    end
    
    it 'should provide revert_to method'  do
      curr_version = WikiEntry.current_version(@attributes)
      prev_version = WikiEntry.version_entry(@attributes.merge(:version => 3, 
        :summary => nil))
      rec = WikiEntry.revert_to(3, @attributes)
      rec.should_not be_new_record
      rec.should be_reverted
      rec.version.should == (curr_version + 1)
      rec.data.should == prev_version.data
      rec.summary.should == 'Reverted to version 3'
    end
    
    it 'should not autoset summary on revert when summary is not null' do
      summary_text = 'Rollbacked to version 3, because of spamming'
      curr_version = WikiEntry.current_version(@attributes)
      prev_version = WikiEntry.version_entry(@attributes.merge(:version => 3))
      rec = WikiEntry.revert_to(3, @attributes.merge(:summary => summary_text))
      rec.should_not be_new_record
      rec.should be_reverted
      rec.version.should == (curr_version + 1)
      rec.data.should == prev_version.data
      rec.summary.should == summary_text
    end
    
    it 'should provide diff method' do
      diff = WikiEntry.diff(4, 5, @attributes)
      diff.should_not be_empty
    end
    
    it 'should provide create method' do
      WikiEntry.should be_respond_to(:create)
    end  
    
  end
  
  describe 'public instance methods interface' do
    
    before do
      setup_default_fixtures
      @wiki_entry = WikiEntry.find(:first)
    end
    
    after do
      clean_database
    end
    
    it 'should provide current_version method' do
      @wiki_entry.current_version.should == 5
    end
    
  end
  
end