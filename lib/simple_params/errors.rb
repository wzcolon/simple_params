require "active_model"

module SimpleParams
  class Errors < ActiveModel::Errors
    attr_reader :base

    def initialize(base, nested_classes = {}, nested_classes_array = [])
      super(base)
      @base = base
      @nested_classes = symbolize_nested(nested_classes)
      @nested_classes_array = nested_classes_array
    end

    def [](attribute)
      if nested_attribute?(attribute)
        set_nested(attribute)
      else
        get(attribute.to_sym) || set(attribute.to_sym, [])
      end
    end

    def []=(attribute, error)
      add_error_to_attribute(attribute, error)
    end

    def add(attribute, message = :invalid, options = {})
      message = normalize_message(attribute, message, options)
      if exception = options[:strict]
        exception = ActiveModel::StrictValidationFailed if exception == true
        raise exception, full_message(attribute, message)
      end

      add_error_to_attribute(attribute, message)
    end

    def clear
      super
      nested_instances.each { |i| i.errors.clear }
    end

    def empty?
      super &&
      nested_instances.all? { |i| i.errors.empty? }
    end
    alias_method :blank?, :empty? 

    def include?(attribute)
      if nested_attribute?(attribute)
        !nested_class(attribute).errors.empty?
      else
        messages[attribute].present?
      end
    end
    alias_method :has_key?, :include? 
    alias_method :key?, :include?

    def values
      messages.values +
      nested_instances.map { |i| i.errors.values }
    end

    def full_messages
      parent_messages = map { |attribute, message| full_message(attribute, message) }
      nested_messages = nested_instances.map do |i| 
        i.errors.full_messages.map { |message| "#{i.parent_attribute_name} " + message }
      end

      (parent_messages + nested_messages).flatten
    end

    def to_hash(full_messages = false)
      msgs = get_messages(self, full_messages)

      @nested_classes.map do |attribute, klass|
        nested_msgs = run_or_mapped_run(klass) do |k| 
          unless k.nil?
            get_messages(k.errors, full_messages)
          end
        end
        unless empty_messages?(nested_msgs)
          msgs.merge!(attribute.to_sym => nested_msgs)
        end
      end

      msgs
    end

    def to_s(full_messages = false)
      array = to_a.compact
      array.join(', ')
    end

    private
    def nested_class(key)
      @nested_classes[key.to_sym]
    end

    def nested_attribute?(attribute)
      @nested_classes.keys.include?(attribute.to_sym)
    end


    def add_error_to_attribute(attribute, error)
      if nested_attribute?(attribute)
        @nested_classes[attribute].errors.add(:base, error)
      else
        self[attribute] << error
      end
    end

    def get_messages(object, full_messages = false)
      if full_messages
        object.messages.each_with_object({}) do |(attribute, array), messages|
          messages[attribute] = array.map { |message| object.full_message(attribute, message) }
        end
      else
        object.messages.dup
      end
    end

    def empty_messages?(msgs)
      msgs.nil? || msgs.empty? || (msgs.is_a?(Array) && msgs.all? { |m| m.nil? || m.empty? })
    end

    def run_or_mapped_run(object, &block)
      if object.is_a?(Array)
        object.map { |obj| yield obj }
      else
        yield object
      end
    end

    def symbolize_nested(nested)
      nested.inject({}) { |memo,(k,v) | memo[k.to_sym] = v; memo }
    end

    def set_nested(attribute)
      klass = nested_class(attribute)
      errors = run_or_mapped_run(klass) { |k| k.errors if k.present? }
      set(attribute.to_sym, errors)
    end

    def nested_instances
      array =[]
      @nested_classes.each do |key, instance|
        if instance.is_a?(Array)
          array << instance
          array = array.flatten.compact
        else
          unless instance.nil?
            array << instance
          end
        end
      end
      array
    end
  end
end
