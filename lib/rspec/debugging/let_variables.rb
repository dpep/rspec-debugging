module RSpec
  module Debugging
    module LetVariables
      def let_variables
        Internal.definitions(self).keys
      end

      def let_variable_initialized?(name)
        __memoized.instance_variable_get("@memoized").key?(Internal.resolve(self, name))
      end

      def let_variable_get(name)
        __memoized.instance_variable_get("@memoized")[Internal.resolve(self, name)]
      end

      def let_variable_reset(name)
        __memoized.instance_variable_get("@memoized").delete(Internal.resolve(self, name))
      end

      def let_variable_locations(name)
        Internal.definitions(self)[Internal.resolve(self, name)].map do |fn|
          Internal.location(fn)
        end
      end

      def let_variable_values(name)
        memo = __memoized.instance_variable_get("@memoized")

        Internal.definitions(self)[Internal.resolve(self, name)].map do |fn|
          snapshot = memo.dup
          value = begin
            fn.bind_call(self)
          rescue => e
            e
          ensure
            memo.replace(snapshot) # forget lets the definition pulled in
          end

          { Internal.location(fn) => value }
        end
      end

      # Helpers live here rather than in the mixin, which is included into
      # every example group and would collide with users' own methods.
      module Internal
        module_function

        # let name => definitions, innermost scope first
        def definitions(example)
          mods = example.class.ancestors.select { |x| x.to_s.include?("::LetDefinitions") }

          mods.each_with_object({}) do |mod, defs|
            mod.instance_methods.each do |name|
              (defs[name] ||= []) << mod.instance_method(name)
            end
          end
        end

        def resolve(example, name)
          name = name.to_sym
          # a named subject is an alias of its let
          name = example.class.instance_method(:subject).original_name if name == :subject
          return name if definitions(example).key?(name)

          raise ArgumentError, "no let variable named #{name.inspect}"
        end

        def location(fn)
          fn.source_location.join(":")
            .delete_prefix(Dir.pwd + "/")
            .gsub(%r{.*/gems/}, ".../gems/")
            .sub(Dir.home, "~")
        end
      end
    end
  end
end
