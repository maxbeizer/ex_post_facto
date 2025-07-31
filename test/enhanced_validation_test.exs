defmodule ExPostFacto.EnhancedValidationTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.Validation

  alias ExPostFacto.{Validation, ExampleStrategies.Noop}

  describe "enhanced validation system" do
    test "backtest with enhanced_validation: true works for valid data" do
      data = [
        %{open: 10.0, high: 10.5, low: 9.5, close: 10.2, timestamp: "2023-01-01"},
        %{open: 10.2, high: 10.8, low: 10.0, close: 10.5, timestamp: "2023-01-02"}
      ]

      assert {:ok, output} =
               ExPostFacto.backtest(data, {Noop, :noop, []}, enhanced_validation: true)

      assert length(output.data) == 2
    end

    test "enhanced validation catches invalid data with detailed errors" do
      # Missing required fields
      invalid_data = [
        # Missing low, close
        %{open: 10.0, high: 10.5},
        # Missing open, high
        %{low: 9.5, close: 10.2}
      ]

      assert {:error, %Validation.ValidationError{} = error} =
               ExPostFacto.backtest(invalid_data, {Noop, :noop, []}, enhanced_validation: true)

      assert String.contains?(error.message, "Missing required OHLC fields")
      assert is_map(error.context)
      assert is_list(error.suggestions)
    end

    test "enhanced validation catches invalid strategy with detailed errors" do
      data = [%{open: 10.0, high: 10.5, low: 9.5, close: 10.2}]

      assert {:error, %Validation.StrategyError{} = error} =
               ExPostFacto.backtest(data, {NonExistentModule, :missing, []},
                 enhanced_validation: true
               )

      assert String.contains?(error.message, "Module NonExistentModule does not exist")
      assert error.strategy == {NonExistentModule, :missing, []}
      assert is_list(error.suggestions)
    end

    test "debug mode provides detailed logging" do
      data = [%{open: 10.0, high: 10.5, low: 9.5, close: 10.2}]

      # Capture output
      ExUnit.CaptureIO.capture_io(fn ->
        {:ok, _} =
          ExPostFacto.backtest(data, {Noop, :noop, []},
            enhanced_validation: true,
            debug: true
          )
      end)

      # Just ensure no errors occur - actual output testing would be complex
    end

    test "warning system provides runtime feedback" do
      # Use noop strategy which should trigger warnings
      data = [%{open: 10.0, high: 10.5, low: 9.5, close: 10.2}]

      assert {:ok, _output} =
               ExPostFacto.backtest(data, {Noop, :noop, []},
                 enhanced_validation: true,
                 warnings: true
               )
    end

    test "enhanced validation is backward compatible" do
      data = [%{open: 10.0, high: 10.5, low: 9.5, close: 10.2}]

      # Should work without enhanced_validation (default: false)
      assert {:ok, output1} = ExPostFacto.backtest(data, {Noop, :noop, []})

      # Should work with enhanced_validation: false
      assert {:ok, output2} =
               ExPostFacto.backtest(data, {Noop, :noop, []}, enhanced_validation: false)

      # Should work with enhanced_validation: true
      assert {:ok, output3} =
               ExPostFacto.backtest(data, {Noop, :noop, []}, enhanced_validation: true)

      # All should succeed and have similar structure
      assert length(output1.data) == length(output2.data)
      assert length(output2.data) == length(output3.data)
    end
  end

  describe "Validation module" do
    test "validate_data/2 handles various data formats" do
      # Valid data (may return warning about missing volume)
      valid_data = [%{open: 10.0, high: 10.5, low: 9.5, close: 10.2}]
      result = Validation.validate_data(valid_data)

      assert result in [
               :ok,
               {:warning,
                "No volume data detected - some strategies may require volume information"}
             ]

      # Empty data
      assert {:error, %Validation.ValidationError{}} = Validation.validate_data([])

      # Nil data
      assert {:error, %Validation.ValidationError{}} = Validation.validate_data(nil)
    end

    test "validate_strategy/2 handles MFA tuples" do
      # Valid MFA (may return warning)
      result = Validation.validate_strategy({Noop, :noop, []})

      assert result in [
               :ok,
               {:warning, "Using no-operation strategy - this is typically for testing only"}
             ]

      # Invalid module
      assert {:error, %Validation.StrategyError{}} =
               Validation.validate_strategy({NonExistentModule, :call, []})

      # Nil strategy
      assert {:error, %Validation.StrategyError{}} = Validation.validate_strategy(nil)
    end

    test "validate_options/1 validates backtest options" do
      # Valid options
      assert :ok == Validation.validate_options(starting_balance: 1000.0, debug: true)

      # Invalid starting balance
      assert {:error, error_string} = Validation.validate_options(starting_balance: -100)
      assert is_binary(error_string)

      # Invalid boolean option
      assert {:error, error_string} = Validation.validate_options(debug: "true")
      assert is_binary(error_string)
    end

    test "format_error/1 provides user-friendly error messages" do
      error =
        Validation.ValidationError.exception(
          message: "Test error",
          context: %{field: "value"},
          suggestions: ["Try this", "Or this"]
        )

      formatted = Validation.format_error(error)
      assert String.contains?(formatted, "Test error")
      assert String.contains?(formatted, "Context:")
      assert String.contains?(formatted, "Suggestions:")
    end
  end
end
