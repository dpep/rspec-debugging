require 'debug'
require 'debug/session'

module RSpec
  module Debugging
    module DebugIt
      ENABLED = ['1', 'true'].include?(ENV['RSPEC_DEBUGGING'])

      # Skip, an expected failure of a pending example, and exit aren't failures.
      # Nor is anything once the run is stopping.
      def self.failure?(error)
        !RSpec.world.wants_to_quit &&
          !RSpec.current_example.pending? &&
          !error.is_a?(RSpec::Core::Pending::SkipDeclaredInExample) &&
          RSpec::Support::AllExceptionsExceptOnesWeMustNotRescue === error
      end

      # Quitting the debugger raises SystemExit, which would end the run as a
      # pass. Stop the run instead; the examples it skips make it fail.
      def self.session
        yield
      rescue SystemExit
        RSpec.world.wants_to_quit = true
      end

      # Hooks in at run time, not in initialize: an extra frame there would
      # become the location RSpec records for blockless examples.
      def run(example_group_instance, reporter)
        # rspec --bisect children keep the TTY on stdin but capture stderr
        if (ENABLED || metadata[:debug]) && $stdin.tty? && $stderr.tty?
          debug_blockless if metadata[:dit] && metadata[:skip] == RSpec::Core::Pending::NOT_YET_IMPLEMENTED
          example_group_instance.extend(Postmortem)
        end

        super
      end

      private

      # A blockless dit opens the debugger instead of being "Not yet implemented".
      def debug_blockless
        metadata.delete(:skip)
        location = self.location

        @example_block = Proc.new do
          $stderr.puts <<~MSG
          debugging: #{location}

          MSG

          DebugIt.session { debugger }
        end
      end

      # Extended onto the example group instance a debugged example runs in.
      module Postmortem
        # rspec-core runs the example body and its before/after hooks (so let!
        # too) as instance_exec(example, &block). Around hooks get a Procsy, and
        # user code passes other args, so a failure is only debugged once. In a
        # thread there is no current example: leave that alone too.
        def instance_exec(*args, &block)
          example = RSpec.current_example
          return super unless example && args.first.equal?(example)

          error = DEBUGGER__::SESSION.capture_exception_frames(%r{(exe|bin|lib)/rspec}) { return super }
          raise error unless DebugIt.failure?(error)

          $stderr.puts <<~MSG

          Error:
          #{error.message}

          MSG

          # names only: values can be huge
          lets = let_variables.select { |name| let_variable_initialized?(name) }
          $stderr.puts "initialized lets: #{lets.join(", ")}\n\n" if lets.any?

          DebugIt.session { DEBUGGER__::SESSION.enter_postmortem_session(error) }
          raise error
        end
      end
    end
  end
end

RSpec::Core::Example.prepend RSpec::Debugging::DebugIt
# :dit marks the example itself; :debug is also inherited from ddescribe/dcontext
RSpec::Core::ExampleGroup.define_example_method(:dit, debug: true, focus: true, dit: true)
RSpec::Core::ExampleGroup.define_example_group_method(:ddescribe, debug: true, focus: true)
RSpec::Core::ExampleGroup.define_example_group_method(:dcontext, debug: true, focus: true)
