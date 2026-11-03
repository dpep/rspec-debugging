rspec-debugging
======
![Gem](https://img.shields.io/gem/dt/rspec-debugging?style=plastic)
[![codecov](https://codecov.io/gh/dpep/rspec-debugging/branch/main/graph/badge.svg)](https://codecov.io/gh/dpep/rspec-debugging)


Tools to make debugging RSpec tests easier.

```ruby
# Gemfile
gem "rspec-debugging"

# spec/spec_helper.rb
require "rspec/debugging"
```

Requires Ruby >= 3.2. The [debug](https://github.com/ruby/debug) gem comes along as a dependency.

<br />

Debug broken specs
----
Swap `it` for `dit` (or `describe` / `context` for `ddescribe` / `dcontext`). When the example fails, you land in the debugger right where it broke, with the stack intact.

```ruby
describe MySpec do
  dit { is_expected.to ... }
end
```

Failures in `before` / `after` hooks and `let!` count too. The debugger prints the error and the names of any `let` variables that were initialized.

Or debug every example, no code changes:
```
RSPEC_DEBUGGING=true bundle exec rspec
```

Tip: `RSPEC_DEBUGGING=true bundle exec rspec --only-failures --fail-fast` debugs the first remaining failure (`--only-failures` needs `config.example_status_persistence_file_path`). Use `rspec path/to/spec.rb:42` to target one example.

<br />

Stop and explore
----
A `dit` with no block is a breakpoint.

```ruby
describe MySpec do
  let(:user) { ... }

  dit
end
```

<br />

Good to know
----
* `dit` and friends tag examples `focus: true`, so they only narrow the run if your config has `config.filter_run_when_matching :focus`.
* Without a TTY on stdin, nothing interactive happens. `dit` runs like `it`, so a stray one won't hang CI.
* Quitting the debugger stops the run, and the run fails.
* `skip` and `pending` don't open the debugger; only real failures do.
* Not covered: `before(:all)` failures, unmet mock expectations, and `aggregate_failures`.

<br />

Got let variables?
----
`let` variables are great, but complexity can obscure their values.

```ruby
describe "a" do
  subject { a }

  let(:a) { "a" }
  let!(:b) { "b" }

  it { is_expected.to eq ??? }

  context "when we nest" do
    let(:a) { "A" + b }

    it { is_expected.to eq ??? }

    context "...and nest" do
      let(:a) { super() * 2 }

      it { is_expected.to eq ??? }
    end
  end
end
```

...add a hundred lines of legacy code and then solve for `a`. Or use tooling :)

```ruby
# inside the innermost example
let_variables                  # => [:a, :b, :subject]
let_variable_initialized?(:a)  # => false
let_variable_initialized?(:b)  # => true, thanks to let!
let_variable_locations(:a)     # => ["spec/a_spec.rb:15", "spec/a_spec.rb:10", "spec/a_spec.rb:4"]
let_variable_values(:a)
# => [
#   { "spec/a_spec.rb:15" => "AbAb" },
#   { "spec/a_spec.rb:10" => "Ab" },
#   { "spec/a_spec.rb:4" => "a" },
# ]
```

Names can be a Symbol or a String. An unknown name raises `ArgumentError`.

### let_variables
* names of all `let` variables in scope (including `subject`)

### let_variable_initialized?(name)
* whether the variable has been evaluated yet in this example

### let_variable_get(name)
* the memoized value, or `nil` if it hasn't been evaluated. Never triggers evaluation.

### let_variable_reset(name)
* forget the memoized value, so the next call re-evaluates it

### let_variable_locations(name)
* every place the variable is defined, innermost first

### let_variable_values(name)
* every place the variable is defined, innermost first, with the value each definition produces
* doesn't memoize anything, so the example carries on as if you never looked. If a definition raises, its error is its value.
* it does run each definition, though, so external side effects (DB writes, HTTP calls) still happen

<br />

----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a Pull Request


<br />

----
### Inspired by

- [@alexdean](https://github.com/alexdean)
- [rspec-debug](https://github.com/ko1/rspec-debug)
