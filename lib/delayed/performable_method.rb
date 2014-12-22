require 'active_support/core_ext/module/delegation'

module Delayed
  class PerformableMethod
    attr_accessor :object, :method_name, :args

    delegate :method, :to => :object

    def initialize(object, method_name, args)
      raise NoMethodError, "undefined method `#{method_name}' for #{object.inspect}" unless object.respond_to?(method_name, true)

      if object.respond_to?(:persisted?) && !object.persisted?
        raise(ArgumentError, "job cannot be created for non-persisted record: #{object.inspect}")
      end

      self.object       = object
      self.args         = args
      self.method_name  = method_name.to_sym
    end

    def display_name
      if object.is_a?(Class)
        "#{object}.#{method_name}"
      else
        "#{object.class}##{method_name}"
      end
    end

    def serializable_object
      self.object
    end

    if defined?(GlobalID)
      GLOBALID_KEY = '_dj_globalid'.freeze

      def object=(newobject)
        if newobject.respond_to?(:to_global_id)
          @object = { GLOBALID_KEY => newobject.to_global_id.to_s }
        else
          @object = newobject
        end
      end

      def object
        if @object.is_a?(Hash) && @object.size == 1 and @object.include?(GLOBALID_KEY)
          @gidlocator ||= GlobalID::Locator.locate @object[GLOBALID_KEY]
        else
          @object
        end
      end

      def serializable_object
        @object # don't call the function
      end
    end

    def perform
      object.send(method_name, *args) if object
    end

    def method_missing(symbol, *args)
      object.send(symbol, *args)
    end

    def respond_to?(symbol, include_private = false)
      super || object.respond_to?(symbol, include_private)
    end
  end
end
