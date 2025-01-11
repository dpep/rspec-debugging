module RSpec
  module Debugging
    module LetVariables
      def let_variables
        let_variable_methods(self).keys
      end

      def let_variable_initialized?(name)
        __memoized.instance_variable_get("@memoized").key?(name)
      end

      def let_variable_get(name)
        __memoized.instance_variable_get("@memoized")[name]
      end

      def let_variable_locations(name)
        let_variable_methods(self)[name].map do |fn|
          normalize_path(fn.source_location.join(":"))
        end
      end

      def let_variable_values(name)
        let_variable_methods(self)[name].map do |fn|
          {
            normalize_path(fn.source_location.join(":")) => fn.bind(self).call
          }
        end
      end

      private

      extend self

      def let_variable_methods(example)
        # find RSpec modules containing `let` blocks
        mods = self.class.ancestors.select {|x| x.to_s.include?('::LetDefinitions') }

        locations = {}

        mods.each do |mod|
          mod.instance_methods.each do |method_name|
            locations[method_name] ||= []
            locations[method_name] << mod.instance_method(method_name)
          end
        end

        locations
      end

      def normalize_path(path)
        path.delete_prefix(
          Dir.pwd + "/"
        ).gsub(
          %r{.*/gems/},
          ".../gems/"
        ).sub(Dir.home, "~")
      end
    end
  end
end
