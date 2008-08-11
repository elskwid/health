module Health
  def self.included(base)
    base.extend(ClassMethods)
    base.check_health :with_db => true    
    
    # add the named route if there isn't already one defined
    unless path = ActionController::Routing::Routes.recognize_path("/check_health") rescue nil
      ActionController::Routing::Routes.add_named_route 'check_health', 'check_health', 
        :controller => base.controller_name, :action => 'check_health_action' 
    end
  end

  module ClassMethods
    def check_health(*args, &block)
      options = args.extract_options!
      class_inheritable_accessor :check_db_health unless defined?(self.check_db_health)
      self.check_db_health = (options[:with_db].nil? ? true : options[:with_db])
      class_inheritable_array :checks_for_health

      checks = args.flatten
      checks << block if block_given?
      self.checks_for_health = checks
    end
  end  

  def check_health_action
    # check db first
    if self.check_db_health
      result = ActiveRecord::Base.connection.execute("select 1") rescue nil
      return render(:text => 'DBDOWN') unless result and result.fetch_hash == {"1" => "1"}
    end
    
    # then any supplied checks
    unless self.checks_for_health.blank?
      self.checks_for_health.each do |check|
        status = case
                 when check.is_a?(Symbol): self.send(check)
                 when check.respond_to?(:call): check.call(self) rescue raise(ActionController::ActionControllerError, 'Cannot yield from a Proc type check.')
                 else raise(ActionController::ActionControllerError, 'A check must be a Symbol, Proc, or Method')
                 end
        return render(:text => "PROCDOWN #{status}") unless status == true
      end 
    end
     
    # all good
    render :text => 'SERVERUP'      
  end
end
