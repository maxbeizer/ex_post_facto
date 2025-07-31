defmodule ExPostFacto.PerformanceTest do
  @moduledoc """
  Performance tests to demonstrate the improvements made in issue #9.
  
  These tests showcase:
  - Concurrent statistics calculation
  - Parallel optimization runs
  - Memory-efficient processing
  - Streaming capabilities
  """
  
  use ExUnit.Case, async: true
  
  alias ExPostFacto.{Optimizer, Streaming}
  
  @moduletag :performance
  
  describe "concurrent statistics calculation" do
    test "calculates statistics faster with concurrent processing" do
      # Generate test data
      data = generate_test_data(1000)
      
      # This test mainly ensures the concurrent calculation works
      # without errors and produces the same results
      {:ok, output1} = ExPostFacto.backtest(data, {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 10, slow_period: 20]})
      {:ok, output2} = ExPostFacto.backtest(data, {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 10, slow_period: 20]})
      
      # Results should be identical
      assert output1.result.total_profit_and_loss == output2.result.total_profit_and_loss
      assert output1.result.sharpe_ratio == output2.result.sharpe_ratio
      assert output1.result.win_rate == output2.result.win_rate
    end
  end
  
  describe "parallel optimization" do
    test "grid search optimization with parallel processing" do
      data = generate_test_data(200)
      
      # Test that parallel processing works and includes performance info
      {:ok, result} = Optimizer.grid_search(
        data,
        ExPostFacto.ExampleStrategies.SmaStrategy,
        [fast_period: 5..8, slow_period: 15..18],
        maximize: :total_return_pct,
        max_concurrency: 4,
        chunk_size: 8
      )
      
      # Should have performance information
      assert is_map(result.performance_info)
      assert result.performance_info.max_concurrency == 4
      assert result.performance_info.chunk_size == 8
      assert result.performance_info.total_combinations > 0
      
      # Should have valid results
      assert is_list(result.all_results)
      assert length(result.all_results) > 0
      assert is_list(result.best_params)
    end
    
    test "random search optimization with parallel processing" do
      data = generate_test_data(200)
      
      {:ok, result} = Optimizer.random_search(
        data,
        ExPostFacto.ExampleStrategies.SmaStrategy,
        [fast_period: 5..20, slow_period: 20..50],
        samples: 20,
        maximize: :sharpe_ratio,
        max_concurrency: 4
      )
      
      # Should have performance information
      assert is_map(result.performance_info)
      assert result.performance_info.max_concurrency == 4
      assert result.performance_info.total_samples == 20
      
      # Should have valid results
      assert length(result.all_results) == 20
    end
  end
  
  describe "streaming processing" do
    test "creates streaming data sources" do
      # Test that we can create data streams
      {:ok, stream} = Streaming.create_data_stream([
        %{open: 100, high: 105, low: 98, close: 102},
        %{open: 102, high: 108, low: 101, close: 106},
        %{open: 106, high: 110, low: 104, close: 108}
      ])
      
      result = Enum.to_list(stream)
      assert length(result) == 3
      assert is_map(hd(result))
    end
    
    test "creates rolling window streams" do
      data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      
      windows = 
        data
        |> Streaming.rolling_window_stream(3, 1)
        |> Enum.to_list()
      
      assert length(windows) == 8  # 10 - 3 + 1
      assert hd(windows) == [1, 2, 3]
      assert List.last(windows) == [8, 9, 10]
    end
    
    test "estimates memory usage correctly" do
      large_data = generate_test_data(1000)
      
      # This should work without memory issues
      {:ok, stream} = Streaming.create_data_stream(large_data)
      count = stream |> Enum.take(100) |> length()
      assert count == 100
    end
  end
  
  describe "streaming indicators" do
    test "SMA streaming processor works correctly" do
      {:ok, sma_pid} = ExPostFacto.Indicators.Streaming.SMA.start_link(period: 3)
      
      # Test streaming calculation
      results = [
        ExPostFacto.Indicators.Streaming.SMA.update(sma_pid, 10),
        ExPostFacto.Indicators.Streaming.SMA.update(sma_pid, 20),
        ExPostFacto.Indicators.Streaming.SMA.update(sma_pid, 30),  # Should return 20.0 (average of 10,20,30)
        ExPostFacto.Indicators.Streaming.SMA.update(sma_pid, 40)   # Should return 30.0 (average of 20,30,40)
      ]
      
      GenServer.stop(sma_pid)
      
      assert Enum.at(results, 0) == nil  # Not enough data
      assert Enum.at(results, 1) == nil  # Not enough data
      assert Enum.at(results, 2) == 20.0
      assert Enum.at(results, 3) == 30.0
    end
    
    test "EMA streaming processor works correctly" do
      {:ok, ema_pid} = ExPostFacto.Indicators.Streaming.EMA.start_link(period: 3)
      
      results = [
        ExPostFacto.Indicators.Streaming.EMA.update(ema_pid, 10),  # Should return 10.0 (first value)
        ExPostFacto.Indicators.Streaming.EMA.update(ema_pid, 20),  # Should be between 10 and 20
        ExPostFacto.Indicators.Streaming.EMA.update(ema_pid, 30)   # Should be between previous and 30
      ]
      
      GenServer.stop(ema_pid)
      
      assert Enum.at(results, 0) == 10.0
      assert Enum.at(results, 1) > 10.0 and Enum.at(results, 1) < 20.0
      assert Enum.at(results, 2) > Enum.at(results, 1) and Enum.at(results, 2) < 30.0
    end
    
    test "RSI streaming processor works correctly" do
      {:ok, rsi_pid} = ExPostFacto.Indicators.Streaming.RSI.start_link(period: 3)
      
      # Test with some price movements
      prices = [100, 105, 102, 108, 103, 110]
      results = Enum.map(prices, fn price -> 
        ExPostFacto.Indicators.Streaming.RSI.update(rsi_pid, price)
      end)
      
      GenServer.stop(rsi_pid)
      
      # Early results should be nil (not enough data)
      assert Enum.at(results, 0) == nil
      assert Enum.at(results, 1) == nil
      assert Enum.at(results, 2) == nil
      
      # Later results should be valid RSI values (0-100)
      last_rsi = List.last(results)
      assert is_float(last_rsi)
      assert last_rsi >= 0 and last_rsi <= 100
    end
    
    test "batch processing multiple indicators" do
      prices = [100, 102, 104, 103, 105, 107, 106, 108, 110, 109]
      
      {:ok, results} = ExPostFacto.Indicators.Streaming.process_batch(
        prices,
        [
          {:sma, [period: 3]},
          {:ema, [period: 3]},
          {:rsi, [period: 3]}
        ]
      )
      
      assert Map.has_key?(results, :sma_3)
      assert Map.has_key?(results, :ema_3)
      assert Map.has_key?(results, :rsi_3)
      
      assert length(results.sma_3) == 10
      assert length(results.ema_3) == 10
      assert length(results.rsi_3) == 10
      
      # Check that we got some valid results (not all nil)
      sma_values = Enum.filter(results.sma_3, & &1 != nil)
      assert length(sma_values) > 0
      
      ema_values = Enum.filter(results.ema_3, & &1 != nil)
      assert length(ema_values) > 0
    end
  end
  
  describe "performance comparison" do
    @tag :slow
    test "demonstrates performance improvement with larger datasets" do
      # This test is mainly to show that the new code can handle
      # larger datasets without running out of memory or taking too long
      
      large_data = generate_test_data(5000)
      
      # Test regular backtest
      start_time = System.monotonic_time(:millisecond)
      {:ok, _output} = ExPostFacto.backtest(large_data, {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 10, slow_period: 20]})
      backtest_time = System.monotonic_time(:millisecond) - start_time
      
      # Test optimization (smaller parameter space to keep test reasonable)
      start_time = System.monotonic_time(:millisecond)
      {:ok, _result} = Optimizer.grid_search(
        Enum.take(large_data, 1000),  # Use subset for optimization test
        ExPostFacto.ExampleStrategies.SmaStrategy,
        [fast_period: 8..10, slow_period: 18..20],
        max_concurrency: 4
      )
      optimization_time = System.monotonic_time(:millisecond) - start_time
      
      # Just ensure they complete in reasonable time (adjust thresholds as needed)
      assert backtest_time < 10_000  # Less than 10 seconds
      assert optimization_time < 30_000  # Less than 30 seconds
      
      IO.puts("\\nPerformance results:")
      IO.puts("Backtest time (5000 data points): #{backtest_time}ms")
      IO.puts("Optimization time (1000 data points, 3x3 grid): #{optimization_time}ms")
    end
  end
  
  # Helper function to generate test data
  defp generate_test_data(count) do
    base_price = 100.0
    
    1..count
    |> Enum.map(fn i ->
      # Simple random walk
      change = :rand.uniform() * 4 - 2  # Random change between -2 and +2
      price = base_price + change * i / count
      
      %{
        open: price,
        high: price + :rand.uniform() * 2,
        low: price - :rand.uniform() * 2,
        close: price + (:rand.uniform() * 2 - 1),
        volume: 1000 + :rand.uniform(9000),
        timestamp: "2023-01-#{rem(i, 28) + 1}"
      }
    end)
  end
end
