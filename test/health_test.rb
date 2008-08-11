require 'test/unit'
require 'health'

require 'rubygems'
gem 'actionpack', '>= 2.0.2'
require 'action_controller'
require 'active_record'
require 'mocha'

class HealthTest < Test::Unit::TestCase
  def setup
    @controller = Class.new(ActionController::Base)
    @controller.instance_eval do 
      @controller_name = 'test'
    end
    @controller.class_eval do 
      def render(options = []); options[:text] end
    end
  end
  
  def teardown
    rs.clear!    
  end
  
  INHERITABLE_METHODS = %w(check_db_health check_db_health= checks_for_health checks_for_health=)
  def test_should_include_methods_with_defaults
    assert [], @controller.methods.grep(/check/)

    @controller.instance_eval { include Health }
    assert_check_health @controller
  end

  def test_should_include_methods_with_defaults_when_calling_check_health
    assert [], @controller.methods.grep(/check/)

    @controller.instance_eval do
       include Health 
       check_health
    end
    assert_check_health @controller
  end

  def test_should_add_check_health_route
    assert [], rs.routes

    @controller.instance_eval { include Health }
  
    assert_equal 1, rs.routes.size
    assert_equal({:controller => "test", :action => 'check_health_action'}, rs.recognize_path("/check_health"))
    assert_equal '/check_health', rs.generate(:controller => 'test', :action => 'check_health_action')
  end

  def test_check_health_without_db
    @controller.instance_eval do
       include Health 
       check_health :with_db => false
    end
    assert_false @controller.check_db_health
  end
  
  def test_check_health_with_explicit_db_check
    @controller.instance_eval do
       include Health 
       check_health :with_db => true
    end
    assert_check_health(@controller)
  end

  def test_check_health_with_block
    @controller.instance_eval do
       include Health 
       check_health do
         "test"
       end
    end
    assert_equal 1, @controller.checks_for_health.size
    assert_equal "test", @controller.checks_for_health.first.call
  end

  def test_check_health_with_one_symbol
    @controller.instance_eval do
       include Health 
       check_health :test
       def test; "test" end
    end
    assert_equal 1, @controller.checks_for_health.size
    assert_equal "test", @controller.send(@controller.checks_for_health.first)
  end

  def test_check_health_with_multiple_symbols
    @controller.instance_eval do
       include Health 
       check_health :test1, :test2
       def test1; "test1" end
       def test2; "test2" end       
    end
    assert_equal 2, @controller.checks_for_health.size
    assert_equal "test1", @controller.send(@controller.checks_for_health.first)
    assert_equal "test2", @controller.send(@controller.checks_for_health.last)
  end

  def test_check_health_with_one_proc
    @controller.instance_eval do
       include Health 
       check_health lambda { "test" }
    end
    assert_equal 1, @controller.checks_for_health.size
    assert_equal "test", @controller.checks_for_health.first.call
  end

  def test_check_health_with_multiple_procs
    @controller.instance_eval do
       include Health 
       check_health lambda { "test1" }, lambda { "test2" }
    end
    assert_equal 2, @controller.checks_for_health.size
    assert_equal "test1", @controller.checks_for_health.first.call
    assert_equal "test2", @controller.checks_for_health.last.call
  end
  
  def test_check_health_with_a_symbol_and_a_block
    @controller.instance_eval do
       include Health 
       check_health :test do
         "test2"
       end
       def test; "test1" end
    end
    assert_equal 2, @controller.checks_for_health.size
    assert_equal "test1", @controller.send(@controller.checks_for_health.first)
    assert_equal "test2", @controller.checks_for_health.last.call
  end

  def test_check_health_with_a_lambda_and_a_block
    @controller.instance_eval do
       include Health 
       check_health lambda { "test1" } do
         "test2"
       end
    end
    assert_equal 2, @controller.checks_for_health.size
    assert_equal "test1", @controller.checks_for_health.first.call
    assert_equal "test2", @controller.checks_for_health.last.call
  end

  def test_check_health_action_no_db
    @controller.instance_eval do
       include Health 
       check_health :with_db => false
    end
    assert_equal 'SERVERUP', @controller.new.check_health_action
  end
  
  def test_check_health_db_error
    ActiveRecord::Base.stubs("connection").raises("any error")
    @controller.instance_eval { include Health }
    assert_equal 'DBDOWN', @controller.new.check_health_action
  end
  
  def test_check_health_action_with_block
    @controller.instance_eval do
       include Health 
       check_health :with_db => false do
         "test"
       end
    end
    assert_equal 'PROCDOWN test', @controller.new.check_health_action
  end

  def test_check_health_with_symbol
    @controller.instance_eval do
       include Health 
       check_health :my_test, :with_db => false
    end
    @controller.class_eval do
      def my_test; "test" end
    end
    assert_equal 'PROCDOWN test', @controller.new.check_health_action
  end
  
  def test_check_health_action_with_proc
    @controller.instance_eval do
       include Health 
       check_health lambda { "test" }, :with_db => false
    end
    assert_equal 'PROCDOWN test', @controller.new.check_health_action
  end

  #                when check.respond_to?(:call): check.call(self) rescue raise(ActionController::ActionControllerError, 'Cannot yield from a Proc type check.')
  #                else raise(ActionController::ActionControllerError, 'A check must be a Symbol, Proc, or Method')
  def test_check_health_action_should_raise_error_with_unknown_check
    @controller.instance_eval do
       include Health 
       check_health "el stringo", :with_db => false
    end
    assert_raises(ActionController::ActionControllerError) { @controller.new.check_health_action }
  end

  def test_check_health_action_should_raise_error_with_proc_yeild
    @controller.instance_eval do
       include Health 
       check_health lambda { yield }, :with_db => false
    end
    assert_raises(ActionController::ActionControllerError) { @controller.new.check_health_action }
  end

  def test_check_health_action_should_raise_error_with_block_yeild
    @controller.instance_eval do
       include Health 
       check_health :with_db => false do
          yield
       end
    end
    assert_raises(ActionController::ActionControllerError) { @controller.new.check_health_action }
  end

  private
  def rs 
    ActionController::Routing::Routes
  end
  
  def assert_false(expression, message=nil)
    assert !expression, message
  end
  
  def assert_sets_equal(a, b, message=nil)
    assert_equal a.to_set, b.to_set
  end

  def assert_check_health(controller)
    assert_sets_equal INHERITABLE_METHODS + %w(check_health),        controller.methods.grep(/check/)
    assert_sets_equal INHERITABLE_METHODS + %w(check_health_action), controller.new.methods.grep(/check/)

    assert controller.check_db_health
    assert_equal [], controller.checks_for_health
  end
end
