require 'debug'
require 'debug/session'

module RSpec
  module Debugging
    module DebugIt
      ENABLED = ['1', 'true'].include?(ENV['RSPEC_DEBUGGING'])

      def initialize(example_group_class, description, user_metadata, example_block=nil)
        if example_block.nil? && user_metadata[:debug] && user_metadata[:skip] == RSpec::Core::Pending::NOT_YET_IMPLEMENTED
          user_metadata.delete(:skip)

          location = RSpec::Core::Metadata.relative_path(caller[2].split(":in").first)

          example_block = Proc.new do
            $stderr.puts <<~MSG
            debugging: #{location}

            MSG

            debugger
          end.tap do |block|
            # redefine source_location to return the correct location
            block.define_singleton_method(:source_location) { location.split(":") }
          end
        end

        super
      end

      def run(example_group_instance, reporter)
        example_group_instance.extend(Postmortem) if ENABLED || metadata[:debug]
        super
      end

      # Extended onto the example group instance a debugged example runs in.
      module Postmortem
        # rspec-core runs the example body and its before/after hooks (so let!
        # too) as instance_exec(example, &block). Around hooks get a Procsy, and
        # user code passes other args, so a failure is only debugged once.
        def instance_exec(*args, &block)
          return super unless args.first.equal?(RSpec.current_example)

          error = DEBUGGER__::SESSION.capture_exception_frames(%r{(exe|bin|lib)/rspec}) { return super }

          $stderr.puts <<~MSG

          Error:
          #{error.message}

          MSG

          DEBUGGER__::SESSION.enter_postmortem_session(error)
          raise error
        end
      end
    end
  end
end

RSpec::Core::Example.prepend RSpec::Debugging::DebugIt
RSpec::Core::ExampleGroup.define_example_method(:dit, debug: true, focus: true)
RSpec::Core::ExampleGroup.define_example_group_method(:ddescribe, debug: true, focus: true)
RSpec::Core::ExampleGroup.define_example_group_method(:dcontext, debug: true, focus: true)
