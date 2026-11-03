module RSpec
  module Debugging
    module LetVariables
      def let_variables
        Internal.definitions(self).keys
      end

      def let_variable_initialized?(name)
        __memoized.instance_variable_get("@memoized").key?(name)
      end

      def let_variable_get(name)
        __memoized.instance_variable_get("@memoized")[name]
      end

      def let_variable_reset(name)
        __memoized.instance_variable_get("@memoized").delete(name)
      end

      def let_variable_locations(name)
        Internal.definitions(self)[name].map do |fn|
          Internal.location(fn)
        end
      end

      def let_variable_values(name)
        Internal.definitions(self)[name].map do |fn|
          { Internal.location(fn) => fn.bind(self).call }
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
