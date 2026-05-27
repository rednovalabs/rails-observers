module ActiveModel
  class DisabledObserversRegistry
    # Preemptively getting ahead of this Rails 7.1 removal: 
    # DEPRECATION WARNING: ActiveSupport::PerThreadRegistry is deprecated and will be removed in Rails 7.1. Use `Module#thread_mattr_accessor` instead.
    thread_mattr_accessor :disabled_observers_per_class
    thread_mattr_accessor :disabled_observers_stacks_per_class
  end
end