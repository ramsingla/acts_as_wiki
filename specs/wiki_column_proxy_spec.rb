require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class SampleActor
  attr_accessor :proxy
end

describe WikiColumnProxy do
  
  describe 'attribute' do
    
    before do
      @actor = SampleActor.create(:name => 'Wiki Column Proxy Actor')
      @actor.proxy = WikiColumnProxy.new(@actor, :biography)
      @user = User.create(:name => 'Wiki User')
      @test_bio = 'Wiki Column Proxy Test Data'
    end
      
    after do
      clean_database
    end
    
    it 'should behave like a string' do
      @actor.proxy.edit(:data => @test_bio)
      @actor.proxy.should === @test_bio
    end
    
    it 'should update column attribute on edit' do
      @actor.biography.should be_nil
      @actor.proxy.edit(:data => @test_bio, :summary => 'initial commit', :sources => 'rspec test').should == @actor.biography
      @actor.biography.should == @test_bio
    end
    
    it 'should test for valid record on valid?' do
      wi = WikiEntry.new(:wikiable => @actor, :user => @user, 
        :column_name => 'biography', :data => @test_bio)
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id)
      @actor.proxy.valid?
      @actor.proxy.valid?.should == wi.valid?
      @actor.proxy.edit(:data => @test_bio, :summary => 'initial commit', :sources => 'rspec test', :user_id => nil)
      wi.user_id = nil
      @actor.proxy.valid?.should == wi.valid?
    end
    
    it 'should create a new wiki_entry and return version number on successful save' do
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save.should == 1
      @actor.proxy.data(:current).should == @actor.biography
      @actor.should_not be_changed
    end
    
    it 'should create a new wiki_entry and return version number on successful save with update false' do
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save(false).should == 1
      @actor.should be_changed
      @actor.proxy.data(:current).should_not == @actor.biography_was
    end
    
    it 'should fail on subsequent save method (without edit) after successful save' do
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save.should_not be_nil
      @actor.proxy.save.should be_nil
    end
    
    it 'should return nil on unsuccesful save' do
       @actor.proxy.save.should be_nil
    end
    
    it 'should return current version number on version' do
      @actor.proxy.version.should == 0
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save
      @actor.proxy.version.should == 1
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save
      @actor.proxy.version.should == 2
    end
    
    it 'should return last updation time of proxy column on updated_at' do
      @actor.proxy.version.should == 0
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save
      @actor.proxy.updated_at.should == WikiEntry.maximum('created_at')
      @actor.proxy.edit(:data => @test_bio, :user_id => @user.id,
        :summary => 'rpec test data', :sources => 'foo')
      @actor.proxy.save
      @actor.proxy.updated_at.should == WikiEntry.maximum('created_at')
    end
    
    it 'should return owner using proxy_owner' do
      @actor.proxy.proxy_owner.should  == @actor
    end
    
    it 'should return target using proxy_target' do
      @actor.proxy.proxy_target.should be_nil
      @actor.proxy.edit(:data => @test_bio)
      @actor.proxy.proxy_target.should == @test_bio
    end
    
  end
  
  describe 'attribute also' do
    
    before do
      setup_default_fixtures
      @actor = SampleActor.find(1)
      @actor.proxy = WikiColumnProxy.new(@actor, :biography)
    end
    
    after do
      clean_database
    end
    
    it 'should get attributes for a particular version' do
      @actor.proxy.attributes(1)['version'].should == 1
      @actor.proxy.attributes(3)['version'].should == 3
      @actor.proxy.attributes(4)['summary'].should == 'Reverted to version 2'
      @actor.proxy.attributes(10).should == {}
      @actor.proxy.attributes(0).should == {}
    end
    
    it 'should find records on find(*args)' do
      @actor.proxy.find(:all).size.should == 5
      @actor.proxy.find(:first).attributes.should == 
        @actor.proxy.attributes(:current)
      @actor.proxy.find(:first, 
        :order => 'version ASC').attributes.should == @actor.proxy.attributes(1)
      @actor.proxy.find(:all, 
        :conditions => ['version > ?', 3]).size.should == 2
    end
    
    it 'should revert to previous version on rollback(ver, user_id)' do
      @actor.biography.should == @actor.proxy.data(:current)
      @actor.proxy.rollback(4, 3).should == 6 
      @actor.proxy.summary.should == 'Reverted to version 4'
      @actor.biography.should == @actor.proxy.data(4)
      @actor.should_not be_changed
    end
    
    it 'should revert to previous version on rollback(ver, user)' do
      @actor.biography.should == @actor.proxy.data(:current)
      @actor.proxy.rollback(4, User.find(3)).should == 6 
      @actor.proxy.summary.should == 'Reverted to version 4'
      @actor.biography.should == @actor.proxy.data(4)
      @actor.should_not be_changed
    end
    
    it 'should revert to previous version on rollback(ver, user_id, summary)' do
      summary_text = "foo summary v4"
      @actor.biography.should == @actor.proxy.data(:current)
      @actor.proxy.rollback(4, 3, summary_text).should == 6 
      @actor.proxy.summary.should == summary_text
      @actor.biography.should == @actor.proxy.data(4)
      @actor.should_not be_changed
    end
    
    it 'should revert to previous version on rollback(ver, user, summary)' do
      summary_text = "foo summary v4"
      @actor.biography.should == @actor.proxy.data(:current)
      @actor.proxy.rollback(4, User.find(3), summary_text).should == 6 
      @actor.proxy.summary.should == summary_text
      @actor.biography.should == @actor.proxy.data(4)
      @actor.should_not be_changed
    end
    
    it 'should fetch old/current version using data method' do
      @actor.proxy.data(:current).should == @actor.biography
      @actor.proxy.data(1).should_not == @actor.biography
      # get current data
      @actor.proxy.data.should == @actor.proxy.find(:first).data
    end
    
    it 'should fetch old/current summary using summary method' do
      @actor.proxy.summary(:current).should == @actor.proxy.find(
        :first).summary
      @actor.proxy.summary(1).should == @actor.proxy.find(:first, 
        :order => 'version ASC').summary
      @actor.proxy.summary.should == @actor.proxy.find(:first).summary 
    end
    
    it 'should fetch old/current sources using sources method' do
      @actor.proxy.sources(:current).should == @actor.proxy.find(
        :first).sources
      @actor.proxy.sources(1).should == @actor.proxy.find(:first, 
        :order => 'version ASC').sources
      @actor.proxy.sources.should == @actor.proxy.find(:first).sources
    end
    
    it 'should fetch old/current author using user' do
      @actor.proxy.user(:current).should == @actor.proxy.find(
        :first).user
      @actor.proxy.user(1).should == @actor.proxy.find(:first, 
        :order => 'version ASC').user
      @actor.proxy.user.should == @actor.proxy.find(:first).user
    end
    
    it 'should fetch old/current author_id using user_id' do
      @actor.proxy.user_id(:current).should == @actor.proxy.find(
        :first).user_id
      @actor.proxy.user_id(1).should == @actor.proxy.find(:first, 
        :order => 'version ASC').user_id
      @actor.proxy.user_id.should == @actor.proxy.find(:first).user_id
    end
    
    it 'should fetch old/current rollback status using rollbacked?' do
      @actor.proxy.rollbacked?(:current).should == @actor.proxy.find(
        :first).reverted?
      @actor.proxy.rollbacked?(4).should == @actor.proxy.find(:first, 
        :conditions => {:version => 4}).reverted?
      @actor.proxy.rollbacked?.should == @actor.proxy.find(:first).reverted?
    end
    
    it 'should return diff between two versions using diff' do
      @actor.proxy.diff(1,1).select{|x| x.action != '=' }.should be_empty
      @actor.proxy.diff(4,2).select{|x| x.action != '=' }.should be_empty #Reverted Version
      @actor.proxy.diff(5,4).select{|x| x.action != '=' }.should_not be_empty
      @actor.proxy.diff(5,4).first.class.should ==  Diff::LCS::ContextChange
    end
    
  end
  
end