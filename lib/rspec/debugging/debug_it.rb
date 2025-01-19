require 'debug/session'

module RSpec
  module Debugging
    module DebugIt
      ENABLED = ['1', 'true'].include?(ENV['RSPEC_DEBUGGING'])

      def initialize(example_group_class, description, user_metadata, example_block=nil)
        return super unless user_metadata[:debug] || ENABLED

        if example_block
          orig_example_block = example_block

          example_block = Proc.new do
            e = DEBUGGER__::SESSION.capture_exception_frames /(exe|bin|lib)\/rspec/ do
              instance_exec(&orig_example_block)
            end

            if e
              STDERR.puts <<~MSG

              Error:
              #{e.message}

              MSG

              DEBUGGER__::SESSION.enter_postmortem_session e
              raise e
            end
          end # Proc.new
        elsif user_metadata[:debug] && user_metadata[:skip] == RSpec::Core::Pending::NOT_YET_IMPLEMENTED
          # called with no block
          user_metadata.delete(:skip)

          file, line = caller[2].split(":")

          example_block = Proc.new do
            STDERR.puts <<~MSG
            debugging: #{file}:#{line}

            MSG

            debugger
          end
        end

        super
      end
    end
  end
end

RSpec::Core::Example.prepend RSpec::Debugging::DebugIt
RSpec::Core::ExampleGroup.define_example_method(:dit, debug: true, focus: true)
RSpec::Core::ExampleGroup.define_example_group_method(:ddescribe, debug: true, focus: true)
RSpec::Core::ExampleGroup.define_example_group_method(:dcontext, debug: true, focus: true)