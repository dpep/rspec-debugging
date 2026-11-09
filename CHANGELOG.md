## Unreleased
- Requires Ruby 3.3 or newer.

###  0.0.6  (2026-11-03)
- fix: an example that closes `$stdin` and then fails skips the postmortem debugger instead of crashing its thread with `IOError: closed stream`

###  0.0.5  (2026-11-03)
- feature: failures in `before` / `after` hooks and `let!` now open the postmortem debugger
- feature: the postmortem banner lists the names of initialized `let` variables
- fix: quitting the debugger no longer ends the run as a pass; the failing example is reported and the run stops with a non-zero exit
- fix: `dit` never opens the debugger when stdin isn't a TTY (CI), so it can't block a run
- fix: `dit` blocks that take the example (`dit "x" do |example|`) receive it again instead of nil
- fix: examples inside `ddescribe` / `dcontext` now open the debugger
- fix: `skip`, `pending` and `exit` no longer open the debugger; only real failures do
- fix: blockless `dit` reports the right location on Ruby 4.0, and blockless `it` / `dit ... do` examples no longer report a location inside rspec-debugging
- fix: declare `debug` and `rspec-core` as runtime dependencies; the gem failed to load (`LoadError: cannot load such file -- debug`) in a bundle without `debug`
- drop Ruby 3.1 (end of life); requires Ruby >= 3.2
- fix: `let_variable_values` no longer memoizes the lets its definitions reference, so inspecting a let doesn't change what the example does next
- fix: `let_variable_values` returns a raising definition's error as that scope's value instead of aborting the whole call
- fix: let helpers accept String names, and raise `ArgumentError` naming an unknown let instead of `undefined method 'map' for nil` (or quietly returning nil/false)
- fix: `let_variable_*(:subject)` follows a named subject (`subject(:thing)`) to its let instead of crashing or returning an outer group's subject
- fix: the gem's private helpers (`normalize_path`, `let_variable_methods`) are no longer mixed into example groups, where they collided with user helpers of the same name
- fix: let helpers work inside `before(:context)` (lets read as uninitialized) instead of raising `undefined method 'key?' for nil`
- fix: `let_variable_values` reports the right value for a definition that calls `super()` after the let has been memoized (it used to build on the memoized value)
- fix: `let_variable_values` passes the current example to `let(:x) { |example| ... }` definitions instead of reporting an `ArgumentError`
- fix: `dit` no longer opens the debugger when stderr isn't a TTY (e.g. `rspec --bisect` children, which showed a bare debugger prompt)
- fix: `--dry-run` reports a blockless `dit` as pending, not passed
- fix: let helpers no longer treat a described class whose name contains `LetDefinitions` as a source of let variables
- fix: `dit` no longer opens the debugger when stdout is redirected (e.g. `rspec -f json > out.json`), which looked like a hang and corrupted the output
- fix: the postmortem no longer hides your own code under `lib/rspec/` or in a project checked out under `lib/rspec-*/`
- fix: a blockless `dit` under `xdescribe`, a skipped group, or `pending` (on the group or itself) stays pending instead of becoming a breakpoint
- fix: debugged examples no longer tag exceptions with debugger state, so rescued errors and failures can be marshaled again, and raising a frozen exception no longer crashes with "exception reentered"
- fix: rspec-debugging's own frames no longer appear in failure backtraces when the gem is loaded from a path or git checkout

###  0.0.4  (2025-02-08)
- dependency fix
- readme
- inspired by

###  0.0.3  (2025-01-21)
- let_variable_reset
- test coverage
- readme

###  0.0.2  (2025-01-14)
- dit - debugging examples

###  0.0.1  (2025-01-10)
- init
