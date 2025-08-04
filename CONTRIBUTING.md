# Contributing to ExPostFacto

Thank you for your interest in contributing to ExPostFacto! This document provides guidelines and information for contributing to this Elixir backtesting library.

## 🚀 Getting Started

### Prerequisites

- Elixir 1.12 or later
- Erlang/OTP 24 or later
- Git

### Setting Up Your Development Environment

1. **Fork and clone the repository:**

   ```bash
   git clone https://github.com/your-username/ex_post_facto.git
   cd ex_post_facto
   ```

2. **Install dependencies:**

   ```bash
   mix deps.get
   ```

3. **Run the test suite to ensure everything works:**

   ```bash
   mix test
   ```

4. **Check code formatting:**
   ```bash
   mix format --check-formatted
   ```

## 📋 Development Guidelines

### Code Formatting and Standards

**Always run `mix format` after making any code changes.** This ensures consistent formatting across the codebase using the standard Elixir formatter configuration defined in `.formatter.exs`.

Follow these Elixir best practices:

- **Documentation**: Include proper `@moduledoc` and `@doc` attributes for all public modules and functions
- **Type Specifications**: Use `@spec` type annotations for all public functions
- **Naming Conventions**: Follow Elixir conventions (snake_case for functions/variables, PascalCase for modules)
- **Pattern Matching**: Prefer pattern matching over conditional statements when possible
- **Error Handling**: Use `{:ok, result}` and `{:error, reason}` tuples consistently
- **Function Design**: Keep functions small and focused on a single responsibility
- **Data Flow**: Use `|>` pipe operator for data transformations
- **Complex Operations**: Use `with` statements for complex nested operations
- **Exception Functions**: Use `!` suffix for functions that raise exceptions (e.g., `backtest!`)

### Code Quality Requirements

1. **No Compiler Warnings**: Fix all compiler warnings when possible
2. **Test Coverage**: Add comprehensive tests for new functionality
3. **Documentation**: Include examples in documentation
4. **Type Safety**: Add type specs for all public functions
5. **Performance**: Consider performance implications for large datasets
6. **Backward Compatibility**: Maintain backward compatibility when modifying public APIs

## 🏗️ Project Architecture

ExPostFacto is a **backtesting library for trading strategies** with the following core architecture:

### Core Modules

- **`ExPostFacto`**: Main entry point with `backtest/3` and `backtest!/3` functions
- **`ExPostFacto.Result`**: Manages backtesting results and statistics compilation
- **`ExPostFacto.DataPoint`**: Represents individual price data points with actions
- **`ExPostFacto.InputData`**: Handles data munging and preprocessing
- **`ExPostFacto.Output`**: Contains the final output structure

### Trading Strategy Framework

- Supports pluggable strategies through module-function-arguments tuples `{Module, :function, args}`
- Example strategies in `ExPostFacto.ExampleStrategies`
- Strategy behaviour pattern for advanced state management

### Trade Statistics Engine

The `ExPostFacto.TradeStats` namespace contains performance metrics calculations:

- `CompilePairs`: Groups buy/sell actions into trade pairs
- `DrawDown`: Calculates drawdown metrics
- `TotalProfitAndLoss`: Computes P&L
- `WinRate`: Computes win statistics
- And more...

## 🧪 Testing Guidelines

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/ex_post_facto_test.exs

# Run tests with coverage
mix test --cover
```

### Test Organization

Tests are organized to mirror the lib structure:

- **Unit tests** for individual modules
- **Integration tests** for end-to-end scenarios
- **Test helpers** for generating mock data (`CandleDataHelper`)

### Writing Good Tests

1. **Descriptive test names** that explain what is being tested
2. **Arrange-Act-Assert pattern** for test structure
3. **Mock data helpers** for consistent test data
4. **Edge case testing** (empty data, nil values, boundary conditions)
5. **Property-based testing** where appropriate
6. **Integration tests** with real market data when possible

## 🔧 Types of Contributions

### 🐛 Bug Reports

When reporting bugs, please include:

1. **Elixir and Erlang versions**
2. **Minimal reproduction example**
3. **Expected vs actual behavior**
4. **Stack trace** (if applicable)
5. **Data samples** that cause the issue (anonymized if needed)

### ✨ Feature Requests

For new features, please:

1. **Check existing issues** to avoid duplicates
2. **Describe the use case** and problem being solved
3. **Propose the API** or interface design
4. **Consider backward compatibility**
5. **Discuss performance implications**

### 📝 Documentation Improvements

Documentation contributions are highly valued:

- **API documentation** improvements
- **Tutorial and guide** enhancements
- **Example strategies** and use cases
- **Performance tips** and best practices
- **Migration guides** for breaking changes

### 🚀 Code Contributions

#### Strategy Examples

New example strategies should:

- Demonstrate specific trading concepts
- Include comprehensive documentation
- Have corresponding tests
- Follow the established patterns

Example structure:

```elixir
defmodule ExPostFacto.ExampleStrategies.MyStrategy do
  @moduledoc """
  A strategy that demonstrates [specific concept].

  ## Example

      {:ok, result} = ExPostFacto.backtest(
        data,
        {ExPostFacto.ExampleStrategies.MyStrategy, [param: value]}
      )
  """

  @doc """
  Strategy implementation with proper documentation.
  """
  @spec call(map(), ExPostFacto.Result.t(), keyword()) :: ExPostFacto.action()
  def call(data, result, opts \\ []) do
    # Implementation
  end
end
```

#### Technical Indicators

New indicators should:

- Follow the existing indicator API patterns
- Include mathematical documentation
- Have comprehensive test coverage
- Handle edge cases (insufficient data, etc.)

#### Performance Improvements

- **Profile before optimizing** to identify actual bottlenecks
- **Benchmark changes** to measure improvement
- **Consider memory usage** alongside execution time
- **Maintain accuracy** while improving performance

## 🔄 Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/my-new-feature
# or
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Write code following the guidelines above
- Add or update tests
- Update documentation
- Run `mix format` to format code
- Ensure tests pass with `mix test`

### 3. Commit Your Changes

Use descriptive commit messages:

```bash
git add .
git commit -m "Add RSI divergence detection strategy

- Implement bullish and bearish divergence detection
- Add comprehensive tests with edge cases
- Include usage examples in documentation"
```

### 4. Push and Create Pull Request

```bash
git push origin feature/my-new-feature
```

Then create a pull request with:

- **Clear description** of changes
- **Link to related issues**
- **Testing instructions**
- **Breaking changes** (if any)

## 📋 Pull Request Checklist

Before submitting a pull request, ensure:

- [ ] **Tests pass**: `mix test` runs without failures
- [ ] **Code formatted**: `mix format` has been run
- [ ] **No warnings**: Code compiles without warnings
- [ ] **Documentation updated**: For new features or API changes
- [ ] **Tests added**: For new functionality
- [ ] **Backward compatibility**: Maintained for public APIs
- [ ] **Performance considered**: For changes affecting large datasets
- [ ] **Examples provided**: For new strategies or features

## 🎯 Areas Needing Contribution

Based on TODOs and planned enhancements:

1. **Concurrent Statistics**: Make trade statistics calculations concurrent
2. **Additional Metrics**: More comprehensive backtesting metrics
3. **Strategy Framework**: Expand strategy capabilities
4. **Performance Optimization**: Memory and speed improvements
5. **Data Sources**: Additional data input formats
6. **Visualization**: Enhanced charting and reporting
7. **Risk Management**: Position sizing and risk controls

## 🤝 Community Guidelines

- **Be respectful** and inclusive in all interactions
- **Help others** learn and contribute
- **Ask questions** when you need clarification
- **Share knowledge** through documentation and examples
- **Follow the code of conduct** (be kind and professional)

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **Discussions**: For questions and general discussion
- **Documentation**: Check existing docs first
- **Code Examples**: Look at existing strategies and tests

## 🏷️ Release Process

For maintainers:

1. **Update CHANGELOG.md** with new features and fixes
2. **Bump version** in `mix.exs`
3. **Run full test suite** including integration tests
4. **Update documentation** if needed
5. **Create git tag** and push
6. **Publish to Hex** with `mix hex.publish`

---

Thank you for contributing to ExPostFacto! Your contributions help make algorithmic trading more accessible to the Elixir community. 🚀

## ⚡ Quick Reference

```bash
# Essential commands
mix deps.get          # Install dependencies
mix test              # Run tests
mix format            # Format code
mix docs              # Generate documentation
```

Remember: **Always run `mix format` before committing!**
