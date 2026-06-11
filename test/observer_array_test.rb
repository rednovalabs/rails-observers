require 'minitest/autorun'
require 'active_model'
require 'rails/observers/active_model/active_model'
require 'models/observers'

class ObserverArrayTest < ActiveSupport::TestCase
  def teardown
    ORM.observers.enable :all
    Budget.observers.enable :all
    Widget.observers.enable :all
  end

  def assert_observer_notified(model_class, observer_class)
    observer_class.instance.before_save_invocations.clear
    model_instance = model_class.new
    model_instance.save
    assert_equal [model_instance], observer_class.instance.before_save_invocations
  end

  def assert_observer_not_notified(model_class, observer_class)
    observer_class.instance.before_save_invocations.clear
    model_instance = model_class.new
    model_instance.save
    assert_equal [], observer_class.instance.before_save_invocations
  end

  test "all observers are enabled by default" do
    assert_observer_notified Widget, WidgetObserver
    assert_observer_notified Budget, BudgetObserver
    assert_observer_notified Widget, AuditTrail
    assert_observer_notified Budget, AuditTrail
  end

  test "can disable individual observers using a class constant" do
    ORM.observers.disable WidgetObserver

    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_notified     Budget, BudgetObserver
    assert_observer_notified     Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can enable individual observers using a class constant" do
    ORM.observers.disable :all
    ORM.observers.enable AuditTrail

    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_not_notified Budget, BudgetObserver
    assert_observer_notified     Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can disable individual observers using a symbol" do
    ORM.observers.disable :budget_observer

    assert_observer_notified     Widget, WidgetObserver
    assert_observer_not_notified Budget, BudgetObserver
    assert_observer_notified     Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can enable individual observers using a symbol" do
    ORM.observers.disable :all
    ORM.observers.enable :audit_trail

    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_not_notified Budget, BudgetObserver
    assert_observer_notified     Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can disable multiple observers at a time" do
    ORM.observers.disable :widget_observer, :budget_observer

    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_not_notified Budget, BudgetObserver
    assert_observer_notified     Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can enable multiple observers at a time" do
    ORM.observers.disable :all
    ORM.observers.enable :widget_observer, :budget_observer

    assert_observer_notified     Widget, WidgetObserver
    assert_observer_notified     Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_not_notified Budget, AuditTrail
  end

  test "can disable all observers using :all" do
    ORM.observers.disable :all

    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_not_notified Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_not_notified Budget, AuditTrail
  end

  test "can enable all observers using :all" do
    ORM.observers.disable :all
    ORM.observers.enable :all

    assert_observer_notified Widget, WidgetObserver
    assert_observer_notified Budget, BudgetObserver
    assert_observer_notified Widget, AuditTrail
    assert_observer_notified Budget, AuditTrail
  end

  test "can disable observers on individual models without affecting those observers on other models" do
    Widget.observers.disable :all
    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_notified     Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can enable observers on individual models without affecting those observers on other models" do
    ORM.observers.disable :all
    Budget.observers.enable AuditTrail

    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_not_notified Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can disable observers for the duration of a block" do
    yielded = false
    ORM.observers.disable :budget_observer do
      yielded = true
      assert_observer_notified     Widget, WidgetObserver
      assert_observer_not_notified Budget, BudgetObserver
      assert_observer_notified     Widget, AuditTrail
      assert_observer_notified     Budget, AuditTrail
    end

    assert yielded
    assert_observer_notified Widget, WidgetObserver
    assert_observer_notified Budget, BudgetObserver
    assert_observer_notified Widget, AuditTrail
    assert_observer_notified Budget, AuditTrail
  end

  test "can enable observers for the duration of a block" do
    yielded = false
    Widget.observers.disable :all

    Widget.observers.enable :all do
      yielded = true
      assert_observer_notified Widget, WidgetObserver
      assert_observer_notified Budget, BudgetObserver
      assert_observer_notified Widget, AuditTrail
      assert_observer_notified Budget, AuditTrail
    end

    assert yielded
    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_notified     Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end

  test "can enable observer without side effects on other threads" do
    Thread.new do
      Widget.observers.disable :audit_trail
    end.join()
    assert_observer_notified Widget, AuditTrail
  end

  test "disabled_observers_per_class registry starts nil in a new thread with no shared default" do
    value_in_thread = :unset
    Thread.new do
      value_in_thread = ActiveModel::DisabledObserversRegistry.disabled_observers_per_class
    end.join
    assert_nil value_in_thread
  end

  test "disabled_observers_stacks_per_class registry starts nil in a new thread with no shared default" do
    value_in_thread = :unset
    Thread.new do
      value_in_thread = ActiveModel::DisabledObserversRegistry.disabled_observers_stacks_per_class
    end.join
    assert_nil value_in_thread
  end

  test "disabling an observer in one thread does not affect a concurrent thread" do
    ready    = false
    done     = false
    mutex    = Mutex.new
    cond     = ConditionVariable.new
    thread_saw_disabled = nil

    t = Thread.new do
      mutex.synchronize { cond.wait(mutex) until ready }
      thread_saw_disabled = Widget.observers.disabled_for?(AuditTrail.instance)
      mutex.synchronize { done = true; cond.signal }
    end

    Widget.observers.disable :audit_trail
    mutex.synchronize { ready = true; cond.signal }
    mutex.synchronize { cond.wait(mutex) until done }
    t.join

    assert_equal false, thread_saw_disabled
  end

  test "transaction stack is not shared across threads" do
    stack_in_thread = :unset
    Widget.observers.disable :audit_trail do
      Thread.new do
        stack_in_thread = ActiveModel::DisabledObserversRegistry.disabled_observers_stacks_per_class
      end.join
    end
    assert_nil stack_in_thread
  end

  test "raises an appropriate error when a developer accidentally enables or disables the wrong class (i.e. Widget instead of WidgetObserver)" do
    assert_raise ArgumentError do
      ORM.observers.enable :widget
    end

    assert_raise ArgumentError do
      ORM.observers.enable Widget
    end

    assert_raise ArgumentError do
      ORM.observers.disable :widget
    end

    assert_raise ArgumentError do
      ORM.observers.disable Widget
    end
  end

  test "allows #enable at the superclass level to override #disable at the subclass level when called last" do
    Widget.observers.disable :all
    ORM.observers.enable :all

    assert_observer_notified Widget, WidgetObserver
    assert_observer_notified Budget, BudgetObserver
    assert_observer_notified Widget, AuditTrail
    assert_observer_notified Budget, AuditTrail
  end

  test "allows #disable at the superclass level to override #enable at the subclass level when called last" do
    Budget.observers.enable :audit_trail
    ORM.observers.disable :audit_trail

    assert_observer_notified     Widget, WidgetObserver
    assert_observer_notified     Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_not_notified Budget, AuditTrail
  end

  test "can use the block form at different levels of the hierarchy" do
    yielded = false
    Widget.observers.disable :all

    ORM.observers.enable :all do
      yielded = true
      assert_observer_notified Widget, WidgetObserver
      assert_observer_notified Budget, BudgetObserver
      assert_observer_notified Widget, AuditTrail
      assert_observer_notified Budget, AuditTrail
    end

    assert yielded
    assert_observer_not_notified Widget, WidgetObserver
    assert_observer_notified     Budget, BudgetObserver
    assert_observer_not_notified Widget, AuditTrail
    assert_observer_notified     Budget, AuditTrail
  end
end

