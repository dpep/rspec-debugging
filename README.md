rspec-debugging
======
![Gem](https://img.shields.io/gem/dt/rspec-debugging?style=plastic)
[![codecov](https://codecov.io/gh/dpep/rspec-debugging/branch/main/graph/badge.svg)](https://codecov.io/gh/dpep/rspec-debugging)


Tools to make debugging RSpec tests easier.


Debug broken specs
----
Use `dit`, `dcontext`, or `ddescribe` to run a subset of examples and and start the debugger if anything breaks.

```ruby
require "rspec/debugging"

describe MySpec do
  dit { is_expected.to ... }
end
```


Stop and explore
----
Drop `dit` anywhere to start a debugger.

```ruby
describe MySpec do
  dit
end
```


Got let variables?
----
`let` variables are great, but complexity can obscure their value.

```ruby
describe RSpec::Debugging do
  describe RSpec::Debugging::LetVariables do
    subject { a }

    let(:a) { "a" }
    let!(:b) { "b" }

    it { is_expected.to be ??? }

    context "when we nest" do
      let(:a) { "A" + b }

      it { is_expected.to be ??? }

      context "...and nest" do
        let(:a) { super() * 2 }

        it { is_expected.to be ??? }
      end
    end
```

...add a hundred lines of legacy code and then solve for `a`.  Or use tooling :)

### let_variables
* Returns the list of variables defined by RSpec `let`


### let_variable_initialized?(name)
* Has the specified let variable been initialized?


### let_variable_get(name)
* Returns the value of a let variable, if initialized

### let_variable_values(name)
* Return all locations where the specified variable has been defined or redefined, and it's value at each location.


----
## Contributing

Yes please  :)

1. Fork it
1. Create your feature branch (`git checkout -b my-feature`)
1. Ensure the tests pass (`bundle exec rspec`)
1. Commit your changes (`git commit -am 'awesome new feature'`)
1. Push your branch (`git push origin my-feature`)
1. Create a Pull Request


----
### Inspired by

- [@alexdean](https://github.com/alexdean)
- [rspec-debug](https://github.com/ko1/rspec-debug)
