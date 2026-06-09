module ActiveModel
  class DisabledObserversRegistry
    thread_mattr_accessor :disabled_observers_per_class
    thread_mattr_accessor :disabled_observers_stacks_per_class
  end
end