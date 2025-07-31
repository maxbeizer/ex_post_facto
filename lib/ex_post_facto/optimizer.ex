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

  # Private helper functions

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
end