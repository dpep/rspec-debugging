require 'debug'
require 'debug/session'

module RSpec
  module Debugging
    module DebugIt
      ENABLED = ['1', 'true'].include?(ENV['RSPEC_DEBUGGING'])

      GEM_LIB = %r{\A#{Regexp.escape(File.expand_path("../..", __dir__))}/}

      # Frames to hide from the postmortem: rspec's gems and executable, and this
      # gem. Anchored to those dirs so user code under lib/rspec/ stays visible.
      HIDDEN_FRAMES = Regexp.union(
        %r{/rspec-(core|expectations|mocks|support)(-[^/]+)?/lib/},
        %r{/(exe|bin)/rspec\z},
        GEM_LIB,
        %r{\A<internal:trace_point>\z},
      )

      # Mirrors debug's SESSION.capture_exception_frames, which tags every
      # exception raised on any thread while it runs, rescued and frozen ones
      # included. This watches only this thread and keeps the frames in a local
      # table, keyed weakly so rescued exceptions can still be collected (not
      # WeakMap: it holds values weakly too, so a GC would drop the frames).
      # Ruby 3.2 lacks WeakKeyMap. Returns [error, frames] for an error that
      # escapes the block.
      def self.capture_frames
        frames = defined?(ObjectSpace::WeakKeyMap) ? ObjectSpace::WeakKeyMap.new : {}.compare_by_identity
        hook = TracePoint.new(:raise) do |tp|
          # C frames have a nil path on Ruby 4.0
          frames[tp.raised_exception] = DEBUGGER__.capture_frames(nil).reject { |f| f.path&.match?(HIDDEN_FRAMES) }
        end

        hook.enable(target_thread: Thread.current) { yield }
      rescue Exception => error
        frames.key?(error) ? [error, frames[error]] : raise
      end

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

      # The console reads stdin and writes stdout; our banner goes to stderr.
      # Any one redirected (rspec -f json > out, --bisect children) or closed
      # (tty? raises on a closed IO) means no one can drive it.
      def self.interactive?
        [$stdin, $stdout, $stderr].all? { |io| !io.closed? && io.tty? } &&
          !RSpec.configuration.dry_run?
      end

      # Hooks in at run time, not in initialize: an extra frame there would
      # become the location RSpec records for blockless examples.
      def run(example_group_instance, reporter)
        if (ENABLED || metadata[:debug]) && DebugIt.interactive?
          debug_blockless if breakpoint?
          example_group_instance.extend(Postmortem)
        end

        super
      end

      private

      # A blockless dit, not otherwise skipped or pending. Its "Not yet
      # implemented" skip overrides one inherited from the group, so ask the group.
      def breakpoint?
        metadata[:dit] &&
          metadata[:skip] == RSpec::Core::Pending::NOT_YET_IMPLEMENTED &&
          !metadata[:pending] &&
          !example_group.metadata[:skip]
      end

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

          error, frames = DebugIt.capture_frames { return super }
          raise error unless DebugIt.failure?(error)

          $stderr.puts <<~MSG

          Error:
          #{error.message}

          MSG

          # names only: values can be huge
          lets = let_variables.select { |name| let_variable_initialized?(name) }
          $stderr.puts "initialized lets: #{lets.join(", ")}\n\n" if lets.any?

          # debug reads the frames from this ivar. Set it on a copy so the
          # user's error stays as raised (it may be frozen, or get marshaled).
          # (A copy that can't be made just skips the session.)
          copy = begin
            error.dup
          rescue Exception
            nil
          end
          if copy
            copy.instance_variable_set(:@__debugger_postmortem_frames, frames)
            DebugIt.session { DEBUGGER__::SESSION.enter_postmortem_session(copy) }
          end
          raise error
        end
      end
    end
  end
end

RSpec::Core::Example.prepend RSpec::Debugging::DebugIt
# a gem install is already hidden by RSpec's /gems/ pattern; this covers a path or git checkout
RSpec.configuration.backtrace_exclusion_patterns << RSpec::Debugging::DebugIt::GEM_LIB
# :dit marks the example itself; :debug is also inherited from ddescribe/dcontext
RSpec::Core::ExampleGroup.define_example_method(:dit, debug: true, focus: true, dit: true)
RSpec::Core::ExampleGroup.define_example_group_method(:ddescribe, debug: true, focus: true)
RSpec::Core::ExampleGroup.define_example_group_method(:dcontext, debug: true, focus: true)
