#
# Column Proxy creates a interface around Column which is to be stored as wiki
# This class has most of the basic instance methods removed, and delegates
# unknown methods to <tt>@target</tt> via <tt>method_missing</tt>.
#
class WikiColumnProxy #:nodoc:
  
  alias_method :proxy_respond_to?, :respond_to?
  alias_method :proxy_extend, :extend
  
  delegate :to_param, :to => :proxy_target
  
  instance_methods.each do |m| 
    undef_method m unless m =~ /(^__|^nil\?$|^send$|proxy_|^object_id$)/ 
  end
  
  def initialize(owner, column_name)
    @cached = Hash.new
    @owner = owner
    @column_name = column_name
    load_target
  end
  
  def save(update=true)
    return nil unless @wiki_entry.save
    version = @wiki_entry.version
    @owner.send(:update_attribute, @column_name, @wiki_entry.data) if update
    load_target
    return version
  end
  
  # attributes
  #   :user_id : required
  #   :summary : optional
  #   :sources : optional
  #   :data    : required
  def edit(attributes={})
    attributes = attributes.stringify_keys
    column_data = attributes.delete('data')
    if column_data && @target != column_data
      @owner.send(:write_attribute, @column_name, column_data)
      load_target
    end
    ['wikiable_id', 'wikiable_type', 'column_name'].each do |attr|
      attributes.delete(attr)
    end
    @wiki_entry.attributes = @wiki_entry.attributes.merge(attributes)
    @target
  end
  
  def valid?
    @wiki_entry.valid?
  end
  
  def nil?
    @target.nil?
  end
  
  def errors
    @wiki_entry.errors
  end
  
  def version
    @wiki_entry.current_version
  end
  
  def rollback(ver, user_id, summary=nil)
    if user_id.is_a? User
      @wiki_entry.user = user_id
    else
      @wiki_entry.user_id = user_id
    end
    @wiki_entry.summary = summary
    record = WikiEntry.revert_to(ver, @wiki_entry.attributes)
    return nil if record.new_record?
    @owner.send(:update_attribute, @column_name, record.data)
    load_target
    record.version
  end
  
  def attributes(ver = version)
    return @cached[ver] unless @cached[ver].blank?
    ver = version if ver == :current
    attributes = @wiki_entry.attributes.symbolize_keys
    attributes.merge!(:version => ver)
    record = WikiEntry.version_entry(attributes)
    @cached[ver] = (record ? record.attributes : {})
  end
  
  def user(ver = version)
    user_id = user_id(ver)
    user_id ? User.find(:first, :conditions => {:id => user_id}) : nil
  end
  
  def user_id(ver = version)
    attributes(ver)['user_id']
  end
  
  def data(ver = version)
    attributes(ver)['data']
  end
  
  def summary(ver = version)
    attributes(ver)['summary']
  end
  
  def sources(ver = version)
    attributes(ver)['sources']
  end
  
  def rollbacked?(ver = version)
    reverted = attributes(ver)['reverted']
    reverted == true || reverted == ActiveRecord::Base.connection.quoted_true
  end
  
  def updated_at
    attributes(:current)['created_at']
  end
  
  def find(*args)
    WikiEntry.history(args.shift, @wiki_entry.attributes, *args)
  end
  
  def diff(ver_a, ver_b)
    WikiEntry.diff(ver_a, ver_b, @wiki_entry.attributes)
  end
  
  def proxy_owner
    @owner
  end
  
  def proxy_target
    @target
  end
  
  # Does the proxy or its \target respond to +symbol+?
  def respond_to?(*args)
    proxy_respond_to?(*args) || (@target.respond_to?(*args))
  end
  
  # Forwards <tt>===</tt> explicitly to the \target because the instance method
  # removal above doesn't catch it. Loads the \target if needed.
  def ===(other)
    other === @target
  end
  
  def reload
    load_target
    self
  end
  
  # Forwards the call to the target. Loads the \target if needed.
  def inspect
    @target.inspect
  end

  def send(method, *args)
    if proxy_respond_to?(method)
      super
    else
      @target.send(method, *args)
    end
  end
  
  protected
  
  def load_target  
    @target = @owner.send(:read_attribute, @column_name)
    @wiki_entry = WikiEntry.new(
      :column_name => @column_name.to_s, 
      :wikiable => @owner,
      :data => @target
    ) if @wiki_entry.nil? || !@wiki_entry.new_record?
    # we want to preserve the changes to other attributes
    if @wiki_entry.changed?
      @wiki_entry.wikiable = @owner
      @wiki_entry.data = @target
      @wiki_entry.column_name = @column_name.to_s
    end
  end
  
  private

  # Forwards any missing method call to the \target.
  def method_missing(method, *args)
    raise NoMethodError unless @target.respond_to?(method)
    if block_given?
      @target.send(method, *args)  { |*block_args| yield(*block_args) }
    else
      @target.send(method, *args)
    end
  end
  
end