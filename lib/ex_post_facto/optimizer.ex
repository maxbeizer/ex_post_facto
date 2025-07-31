defmodule ExPostFacto.Optimizer do
  @moduledoc """
  Parameter optimization framework for trading strategies.

  Provides various optimization methods to find optimal strategy parameters:
  - Grid search optimization
  - Random search
  - Walk-forward analysis
  - Parameter heatmaps

  ## Example Usage

      # Grid search optimization
      results = ExPostFacto.Optimizer.grid_search(
        market_data,
        MyStrategy,
        [fast: 5..20, slow: 20..50],
        maximize: :sharpe_ratio
      )

  """

  alias ExPostFacto.{Result, Output}

  @type optimization_method :: :grid_search | :random_search | :walk_forward
  @type optimization_metric :: 
    :sharpe_ratio | :total_return_pct | :cagr_pct | :profit_factor | 
    :sqn | :win_rate | :max_draw_down_percentage

  @type parameter_range :: Range.t() | [any()]
  @type parameter_ranges :: [{atom(), parameter_range()}]
  
  @type optimization_result :: %{
    best_params: keyword(),
    best_score: float(),
    best_output: Output.t(),
    all_results: [%{params: keyword(), score: float(), output: Output.t()}],
    method: optimization_method(),
    metric: optimization_metric()
  }

  @doc """
  Perform grid search optimization on strategy parameters.

  Runs backtests for all combinations of parameter values within the specified ranges
  and returns the combination that optimizes the target metric.

  ## Parameters

  - `data` - Market data for backtesting
  - `strategy_module` - Strategy module to optimize
  - `param_ranges` - Keyword list of parameter names to ranges
  - `opts` - Options including `:maximize` metric and backtesting options

  ## Options

  - `:maximize` - Metric to optimize (default: `:sharpe_ratio`)
  - `:starting_balance` - Starting balance for backtests (default: 10_000.0)
  - `:max_combinations` - Maximum parameter combinations to test (default: 1000)

  ## Example

      results = ExPostFacto.Optimizer.grid_search(
        market_data,
        SmaStrategy,
        [fast_period: 5..15, slow_period: 20..30],
        maximize: :sharpe_ratio,
        starting_balance: 100_000.0
      )

  """
  @spec grid_search(
    data :: [map()],
    strategy_module :: atom(),
    param_ranges :: parameter_ranges(),
    opts :: keyword()
  ) :: {:ok, optimization_result()} | {:error, String.t()}
  def grid_search(data, strategy_module, param_ranges, opts \\ []) do
    metric = Keyword.get(opts, :maximize, :sharpe_ratio)
    max_combinations = Keyword.get(opts, :max_combinations, 1000)
    backtest_opts = Keyword.drop(opts, [:maximize, :max_combinations])
    
    # Generate all parameter combinations
    case generate_parameter_combinations(param_ranges, max_combinations) do
      {:ok, combinations} ->
        # Run backtests for all combinations
        results = run_optimization_backtests(data, strategy_module, combinations, metric, backtest_opts)
        
        case find_best_result(results, metric) do
          {:ok, best_result} ->
            {:ok, %{
              best_params: best_result.params,
              best_score: best_result.score,
              best_output: best_result.output,
              all_results: results,
              method: :grid_search,
              metric: metric
            }}
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Perform random search optimization on strategy parameters.

  Randomly samples parameter combinations within the specified ranges
  and returns the combination that optimizes the target metric.

  ## Parameters

  - `data` - Market data for backtesting
  - `strategy_module` - Strategy module to optimize
  - `param_ranges` - Keyword list of parameter names to ranges
  - `opts` - Options including `:maximize` metric and `:samples` count

  ## Options

  - `:maximize` - Metric to optimize (default: `:sharpe_ratio`)
  - `:samples` - Number of random samples to test (default: 100)
  - `:starting_balance` - Starting balance for backtests (default: 10_000.0)

  """
  @spec random_search(
    data :: [map()],
    strategy_module :: atom(),
    param_ranges :: parameter_ranges(),
    opts :: keyword()
  ) :: {:ok, optimization_result()} | {:error, String.t()}
  def random_search(data, strategy_module, param_ranges, opts \\ []) do
    metric = Keyword.get(opts, :maximize, :sharpe_ratio)
    samples = Keyword.get(opts, :samples, 100)
    backtest_opts = Keyword.drop(opts, [:maximize, :samples])
    
    # Generate random parameter combinations
    case generate_random_combinations(param_ranges, samples) do
      {:ok, combinations} ->
        # Run backtests for all combinations
        results = run_optimization_backtests(data, strategy_module, combinations, metric, backtest_opts)
        
        case find_best_result(results, metric) do
          {:ok, best_result} ->
            {:ok, %{
              best_params: best_result.params,
              best_score: best_result.score,
              best_output: best_result.output,
              all_results: results,
              method: :random_search,
              metric: metric
            }}
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate a parameter heatmap from optimization results.

  Creates a 2D heatmap visualization data structure for two-parameter optimization results.
  Useful for visualizing the parameter space and identifying optimal regions.

  ## Parameters

  - `optimization_result` - Result from grid_search or random_search
  - `x_param` - Parameter name for X-axis
  - `y_param` - Parameter name for Y-axis

  ## Returns

  Returns `{:ok, heatmap_data}` where heatmap_data is a map containing:
  - `:x_values` - Sorted list of X parameter values
  - `:y_values` - Sorted list of Y parameter values
  - `:scores` - 2D list of scores (scores[y][x])
  - `:x_param` - X parameter name
  - `:y_param` - Y parameter name

  ## Example

      {:ok, heatmap} = ExPostFacto.Optimizer.heatmap(results, :fast_period, :slow_period)
      
      # Access heatmap data
      x_values = heatmap.x_values     # [5, 6, 7, ...]
      y_values = heatmap.y_values     # [15, 16, 17, ...]
      scores = heatmap.scores         # [[0.1, 0.2, ...], [0.3, 0.4, ...], ...]

  """
  @spec heatmap(optimization_result(), atom(), atom()) :: 
    {:ok, map()} | {:error, String.t()}
  def heatmap(optimization_result, x_param, y_param) do
    case validate_heatmap_params(optimization_result, x_param, y_param) do
      :ok ->
        generate_heatmap_data(optimization_result, x_param, y_param)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Walk-forward analysis optimization.

  Performs optimization using a walk-forward approach where parameters are
  optimized on a training window and tested on a following validation window.
  This helps evaluate strategy robustness over time.

  ## Parameters

  - `data` - Market data for backtesting (must have sufficient length)
  - `strategy_module` - Strategy module to optimize
  - `param_ranges` - Keyword list of parameter names to ranges
  - `opts` - Options including window sizes and optimization settings

  ## Options

  - `:training_window` - Number of data points for training (default: 100)
  - `:validation_window` - Number of data points for validation (default: 50)
  - `:step_size` - Step size for moving the window (default: 25)
  - `:maximize` - Metric to optimize (default: `:sharpe_ratio`)
  - `:optimization_method` - Method for each window (`:grid_search` or `:random_search`) (default: `:grid_search`)

  ## Returns

  Returns `{:ok, walk_forward_result}` containing:
  - `:windows` - List of results for each walk-forward window
  - `:summary` - Aggregated performance metrics
  - `:parameters_stability` - Analysis of parameter stability across windows

  """
  @spec walk_forward(
    data :: [map()],
    strategy_module :: atom(),
    param_ranges :: parameter_ranges(),
    opts :: keyword()
  ) :: {:ok, map()} | {:error, String.t()}
  def walk_forward(data, strategy_module, param_ranges, opts \\ []) do
    training_window = Keyword.get(opts, :training_window, 100)
    validation_window = Keyword.get(opts, :validation_window, 50)
    step_size = Keyword.get(opts, :step_size, 25)
    metric = Keyword.get(opts, :maximize, :sharpe_ratio)
    optimization_method = Keyword.get(opts, :optimization_method, :grid_search)
    
    window_size = training_window + validation_window
    
    if length(data) < window_size do
      {:error, "Insufficient data for walk-forward analysis. Need at least #{window_size} data points."}
    else
      case run_walk_forward_windows(data, strategy_module, param_ranges, 
                                    training_window, validation_window, step_size, 
                                    metric, optimization_method, opts) do
        {:ok, windows} ->
          summary = calculate_walk_forward_summary(windows)
          stability = analyze_parameter_stability(windows)
          
          {:ok, %{
            windows: windows,
            summary: summary,
            parameters_stability: stability,
            method: :walk_forward,
            training_window: training_window,
            validation_window: validation_window,
            step_size: step_size
          }}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @spec generate_parameter_combinations(parameter_ranges(), integer()) :: 
    {:ok, [keyword()]} | {:error, String.t()}
  defp generate_parameter_combinations(param_ranges, max_combinations) do
    try do
      # Convert ranges to lists of values
      param_lists = Enum.map(param_ranges, fn {key, range} ->
        {key, expand_range(range)}
      end)
      
      # Generate cartesian product of all parameter combinations
      combinations = cartesian_product(param_lists)
      
      if length(combinations) > max_combinations do
        {:error, "Too many parameter combinations (#{length(combinations)}), limit is #{max_combinations}"}
      else
        {:ok, combinations}
      end
    rescue
      e -> {:error, "Failed to generate parameter combinations: #{Exception.message(e)}"}
    end
  end

  @spec generate_random_combinations(parameter_ranges(), integer()) :: 
    {:ok, [keyword()]} | {:error, String.t()}
  defp generate_random_combinations(param_ranges, samples) do
    try do
      combinations = Enum.map(1..samples, fn _ ->
        Enum.map(param_ranges, fn {key, range} ->
          {key, random_from_range(range)}
        end)
      end)
      
      {:ok, combinations}
    rescue
      e -> {:error, "Failed to generate random combinations: #{Exception.message(e)}"}
    end
  end

  @spec expand_range(parameter_range()) :: [any()]
  defp expand_range(%Range{} = range), do: Enum.to_list(range)
  defp expand_range(list) when is_list(list), do: list
  defp expand_range(value), do: [value]

  @spec random_from_range(parameter_range()) :: any()
  defp random_from_range(%Range{} = range) do
    list = Enum.to_list(range)
    Enum.random(list)
  end
  defp random_from_range(list) when is_list(list), do: Enum.random(list)
  defp random_from_range(value), do: value

  @spec cartesian_product([{atom(), [any()]}]) :: [keyword()]
  defp cartesian_product([]), do: [[]]
  defp cartesian_product([{key, values} | rest]) do
    rest_products = cartesian_product(rest)
    for value <- values, rest_product <- rest_products do
      [{key, value} | rest_product]
    end
  end

  @spec run_optimization_backtests(
    [map()], 
    atom(), 
    [keyword()], 
    optimization_metric(), 
    keyword()
  ) :: [%{params: keyword(), score: float() | nil, output: Output.t() | nil}]
  defp run_optimization_backtests(data, strategy_module, combinations, metric, backtest_opts) do
    Enum.map(combinations, fn params ->
      case ExPostFacto.backtest(data, {strategy_module, params}, backtest_opts) do
        {:ok, output} ->
          score = extract_metric_score(output.result, metric)
          %{params: params, score: score, output: output}
        {:error, _reason} ->
          %{params: params, score: nil, output: nil}
      end
    end)
  end

  @spec extract_metric_score(Result.t(), optimization_metric()) :: float() | nil
  defp extract_metric_score(result, metric) do
    case metric do
      :sharpe_ratio -> Map.get(result, :sharpe_ratio, 0.0)
      :total_return_pct -> Map.get(result, :total_return_pct, 0.0)
      :cagr_pct -> Map.get(result, :cagr_pct, 0.0)
      :profit_factor -> Map.get(result, :profit_factor, 0.0)
      :sqn -> Map.get(result, :sqn, 0.0)
      :win_rate -> Map.get(result, :win_rate, 0.0)
      :max_draw_down_percentage -> 
        # For drawdown, we want to minimize (maximize negative)
        -(Map.get(result, :max_draw_down_percentage, 100.0))
      _ -> 0.0
    end
  end

  @spec find_best_result([%{params: keyword(), score: float() | nil, output: Output.t() | nil}], optimization_metric()) :: 
    {:ok, %{params: keyword(), score: float(), output: Output.t()}} | {:error, String.t()}
  defp find_best_result(results, _metric) do
    valid_results = Enum.filter(results, fn %{score: score} -> score != nil end)
    
    if Enum.empty?(valid_results) do
      {:error, "No valid backtest results found"}
    else
      best_result = Enum.max_by(valid_results, fn %{score: score} -> score end)
      {:ok, best_result}
    end
  end

  # Helper functions for new features

  @spec validate_heatmap_params(optimization_result(), atom(), atom()) :: 
    :ok | {:error, String.t()}
  defp validate_heatmap_params(result, x_param, y_param) do
    cond do
      not is_map(result) or not Map.has_key?(result, :all_results) ->
        {:error, "Invalid optimization result"}
      x_param == y_param ->
        {:error, "X and Y parameters must be different"}
      true ->
        # Check if parameters exist in results
        sample_result = List.first(result.all_results)
        if sample_result && Map.has_key?(sample_result, :params) do
          params = sample_result.params
          cond do
            not Keyword.has_key?(params, x_param) ->
              {:error, "Parameter #{x_param} not found in optimization results"}
            not Keyword.has_key?(params, y_param) ->
              {:error, "Parameter #{y_param} not found in optimization results"}
            true ->
              :ok
          end
        else
          {:error, "No valid results found for heatmap generation"}
        end
    end
  end

  @spec generate_heatmap_data(optimization_result(), atom(), atom()) :: {:ok, map()}
  defp generate_heatmap_data(result, x_param, y_param) do
    # Extract all parameter combinations and scores
    data_points = Enum.map(result.all_results, fn %{params: params, score: score} ->
      {Keyword.get(params, x_param), Keyword.get(params, y_param), score || 0.0}
    end)
    
    # Get unique parameter values and sort them
    x_values = data_points |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
    y_values = data_points |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort()
    
    # Create 2D score matrix
    scores = Enum.map(y_values, fn y ->
      Enum.map(x_values, fn x ->
        # Find score for this x,y combination
        case Enum.find(data_points, fn {px, py, _} -> px == x && py == y end) do
          {_, _, score} -> score
          nil -> 0.0
        end
      end)
    end)
    
    {:ok, %{
      x_values: x_values,
      y_values: y_values,
      scores: scores,
      x_param: x_param,
      y_param: y_param
    }}
  end

  @spec run_walk_forward_windows(
    [map()], atom(), parameter_ranges(), integer(), integer(), integer(),
    optimization_metric(), optimization_method(), keyword()
  ) :: {:ok, [map()]} | {:error, String.t()}
  defp run_walk_forward_windows(data, strategy_module, param_ranges, 
                                training_window, validation_window, step_size,
                                metric, optimization_method, opts) do
    window_size = training_window + validation_window
    data_length = length(data)
    
    windows = for start_idx <- 0..(data_length - window_size)//step_size do
      training_data = Enum.slice(data, start_idx, training_window)
      validation_data = Enum.slice(data, start_idx + training_window, validation_window)
      
      # Optimize on training data
      optimization_opts = Keyword.drop(opts, [:training_window, :validation_window, :step_size, :optimization_method])
      optimization_result = case optimization_method do
        :grid_search ->
          grid_search(training_data, strategy_module, param_ranges, 
                     Keyword.put(optimization_opts, :maximize, metric))
        :random_search ->
          random_search(training_data, strategy_module, param_ranges,
                       Keyword.put(optimization_opts, :maximize, metric))
      end
      
      case optimization_result do
        {:ok, opt_result} ->
          # Test optimized parameters on validation data
          best_params = opt_result.best_params
          validation_opts = Keyword.drop(optimization_opts, [:maximize, :max_combinations, :samples])
          
          case ExPostFacto.backtest(validation_data, {strategy_module, best_params}, validation_opts) do
            {:ok, validation_output} ->
              validation_score = extract_metric_score(validation_output.result, metric)
              
              %{
                window_start: start_idx,
                training_result: opt_result,
                validation_score: validation_score,
                validation_output: validation_output,
                best_params: best_params
              }
            {:error, _} ->
              %{
                window_start: start_idx,
                training_result: opt_result,
                validation_score: nil,
                validation_output: nil,
                best_params: best_params
              }
          end
        {:error, _} ->
          %{
            window_start: start_idx,
            training_result: nil,
            validation_score: nil,
            validation_output: nil,
            best_params: []
          }
      end
    end
    
    {:ok, windows}
  end

  @spec calculate_walk_forward_summary([map()]) :: map()
  defp calculate_walk_forward_summary(windows) do
    valid_windows = Enum.filter(windows, fn %{validation_score: score} -> score != nil end)
    
    if Enum.empty?(valid_windows) do
      %{
        total_windows: length(windows),
        valid_windows: 0,
        average_validation_score: 0.0,
        best_validation_score: 0.0,
        worst_validation_score: 0.0
      }
    else
      validation_scores = Enum.map(valid_windows, fn %{validation_score: score} -> score end)
      
      %{
        total_windows: length(windows),
        valid_windows: length(valid_windows),
        average_validation_score: Enum.sum(validation_scores) / length(validation_scores),
        best_validation_score: Enum.max(validation_scores),
        worst_validation_score: Enum.min(validation_scores)
      }
    end
  end

  @spec analyze_parameter_stability([map()]) :: map()
  defp analyze_parameter_stability(windows) do
    valid_windows = Enum.filter(windows, fn %{best_params: params} -> params != [] end)
    
    if Enum.empty?(valid_windows) do
      %{stability_analysis: "No valid parameter sets found"}
    else
      # Extract all parameter names
      all_params = valid_windows
                  |> Enum.flat_map(fn %{best_params: params} -> Keyword.keys(params) end)
                  |> Enum.uniq()
      
      # Calculate stability for each parameter
      stability_metrics = Enum.map(all_params, fn param_name ->
        values = Enum.map(valid_windows, fn %{best_params: params} ->
          Keyword.get(params, param_name)
        end)
        
        unique_values = Enum.uniq(values)
        stability_ratio = length(unique_values) / length(values)
        
        {param_name, %{
          unique_values: length(unique_values),
          total_windows: length(values),
          stability_ratio: stability_ratio,
          most_common: find_most_common_value(values)
        }}
      end) |> Enum.into(%{})
      
      %{
        parameter_stability: stability_metrics,
        overall_stability: calculate_overall_stability(stability_metrics)
      }
    end
  end

  @spec find_most_common_value([any()]) :: any()
  defp find_most_common_value(values) do
    values
    |> Enum.frequencies()
    |> Enum.max_by(fn {_value, count} -> count end)
    |> elem(0)
  end

  @spec calculate_overall_stability(map()) :: float()
  defp calculate_overall_stability(stability_metrics) when map_size(stability_metrics) == 0, do: 0.0
  defp calculate_overall_stability(stability_metrics) do
    ratios = Map.values(stability_metrics) |> Enum.map(fn %{stability_ratio: ratio} -> ratio end)
    Enum.sum(ratios) / length(ratios)
  end
end