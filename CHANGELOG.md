###  Unreleased
- fix: declare `debug` and `rspec-core` as runtime dependencies; the gem failed to load (`LoadError: cannot load such file -- debug`) in a bundle without `debug`
- drop Ruby 3.1 (end of life); requires Ruby >= 3.2
- fix: `let_variable_values` no longer memoizes the lets its definitions reference, so inspecting a let doesn't change what the example does next
- fix: `let_variable_values` returns a raising definition's error as that scope's value instead of aborting the whole call
- fix: let helpers accept String names, and raise `ArgumentError` naming an unknown let instead of `undefined method 'map' for nil` (or quietly returning nil/false)
- fix: `let_variable_*(:subject)` follows a named subject (`subject(:thing)`) to its let instead of crashing or returning an outer group's subject
- fix: the gem's private helpers (`normalize_path`, `let_variable_methods`) are no longer mixed into example groups, where they collided with user helpers of the same name
- fix: let helpers work inside `before(:context)` (lets read as uninitialized) instead of raising `undefined method 'key?' for nil`

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
