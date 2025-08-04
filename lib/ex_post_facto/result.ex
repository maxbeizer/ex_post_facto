defmodule ExPostFacto.Result do
  @moduledoc """
  The result contains the output of applying a strategy to a set of data.
  """
  alias ExPostFacto.TradeStats.DrawDown
  alias ExPostFacto.DataPoint

  alias ExPostFacto.TradeStats.{
    DrawDown,
    Duration,
    TradeDuration,
    TradePercentage,
    CompilePairs,
    TotalProfitAndLoss,
    WinRate,
    FinancialRatios,
    ProfitMetrics,
    SystemQuality,
    KellyCriterion,
    MarketRisk
  }

  # Performance optimizations implemented:
  # - Concurrent statistics calculation using Task.async_stream
  # - Parallel metric computation for improved throughput
  # Start                     2004-08-19 00:00:00
  # End                       2013-03-01 00:00:00
  # Duration                   3116 days 00:00:00
  # Exposure Time [%]                       94.27
  # Equity Final [$]                     68935.12
  # Equity Peak [$]                      68991.22
  # Return [%]                             589.35
  # Buy & Hold Return [%]                  703.46
  # Return (Ann.) [%]                       25.42
  # Volatility (Ann.) [%]                   38.43
  # Sharpe Ratio                             0.66
  # Sortino Ratio                            1.30
  # Calmar Ratio                             0.77
  # Max. Drawdown [%]                      -33.08
  # Avg. Drawdown [%]                       -5.58
  # Max. Drawdown Duration      688 days 00:00:00
  # Avg. Drawdown Duration       41 days 00:00:00
  # # Trades                                   93
  # Win Rate [%]                            53.76
  # Best Trade [%]                          57.12
  # Worst Trade [%]                        -16.63
  # Avg. Trade [%]                           1.96
  # Max. Trade Duration         121 days 00:00:00
  # Avg. Trade Duration          32 days 00:00:00
  # Profit Factor                            2.13
  # Expectancy [%]                           6.91
  # SQN                                      1.78
  # _strategy              SmaCross(n1=10, n2=20)

  defstruct data_points: [],
            is_position_open: false,
            starting_balance: 0.0,
            total_profit_and_loss: 0.0,
            max_draw_down: 0.0,
            start_date: nil,
            end_date: nil,
            duration: nil,
            trades_count: 0,
            win_rate: 0.0,
            win_count: 0,
            trade_pairs: [],
            max_draw_down_percentage: 0.0,
            average_draw_down_percentage: 0.0,
            max_draw_down_duration: 0.0,
            average_draw_down_duration: 0.0,
            best_trade_by_percentage: 0.0,
            worst_trade_by_percentage: 0.0,
            average_trade_by_percentage: 0.0,
            max_trade_duration: 0.0,
            average_trade_duration: 0.0,
            # Comprehensive statistics
            total_return_pct: 0.0,
            cagr_pct: 0.0,
            sharpe_ratio: 0.0,
            sortino_ratio: 0.0,
            calmar_ratio: 0.0,
            profit_factor: 0.0,
            expectancy: 0.0,
            expectancy_pct: 0.0,
            sqn: 0.0,
            sqn_interpretation: "",
            kelly_criterion: 0.0,
            kelly_interpretation: "",
            annual_volatility: 0.0,
            alpha: 0.0,
            beta: 0.0,
            information_ratio: 0.0,
            tracking_error: 0.0,
            market_correlation: 0.0,
            gross_profit: 0.0,
            gross_loss: 0.0,
            average_winning_trade: 0.0,
            average_losing_trade: 0.0,
            largest_winning_trade: 0.0,
            largest_losing_trade: 0.0

  @type t :: %__MODULE__{
          data_points: [DataPoint.t()],
          is_position_open: boolean(),
          starting_balance: float(),
          total_profit_and_loss: float(),
          max_draw_down: float(),
          start_date: String.t() | nil,
          end_date: String.t() | nil,
          duration: float() | nil,
          trades_count: integer(),
          win_rate: float(),
          win_count: integer(),
          trade_pairs: [ExPostFacto.TradeStats.TradePair.t()],
          max_draw_down_percentage: float(),
          average_draw_down_percentage: float(),
          max_draw_down_duration: float(),
          average_draw_down_duration: float(),
          best_trade_by_percentage: float(),
          worst_trade_by_percentage: float(),
          average_trade_by_percentage: float(),
          max_trade_duration: float(),
          average_trade_duration: float(),
          total_return_pct: float(),
          cagr_pct: float(),
          sharpe_ratio: float(),
          sortino_ratio: float(),
          calmar_ratio: float(),
          profit_factor: float(),
          expectancy: float(),
          expectancy_pct: float(),
          sqn: float(),
          sqn_interpretation: String.t(),
          kelly_criterion: float(),
          kelly_interpretation: String.t(),
          annual_volatility: float(),
          alpha: float(),
          beta: float(),
          information_ratio: float(),
          tracking_error: float(),
          market_correlation: float(),
          gross_profit: float(),
          gross_loss: float(),
          average_winning_trade: float(),
          average_losing_trade: float(),
          largest_winning_trade: float(),
          largest_losing_trade: float()
        }

  @doc """
  Creates a new result struct.
  """
  @spec new(
          starting_balance: float(),
          start_date: String.t(),
          end_date: String.t()
        ) :: %__MODULE__{}
  def new(options \\ []) do
    starting_balance = Keyword.get(options, :starting_balance, 0.0)
    start_date = Keyword.get(options, :start_date)
    end_date = Keyword.get(options, :end_date)

    %__MODULE__{
      starting_balance: starting_balance,
      start_date: start_date,
      end_date: end_date,
      duration: Duration.call!(start_date, end_date)
    }
  end

  @spec add_data_point(
          result :: %__MODULE__{},
          index :: integer(),
          datum :: map(),
          action :: ExPostFacto.action()
        ) :: %__MODULE__{}
  def add_data_point(result, index, datum, action) do
    data_point = DataPoint.new(datum, action, index)

    case add_data_point?(result, action) do
      true ->
        update_result(result, data_point, action)

      false ->
        result
    end
  end

  @spec update_result(
          result :: %__MODULE__{},
          data_point :: %DataPoint{},
          action :: ExPostFacto.action()
        ) :: %__MODULE__{}
  defp update_result(result, data_point, action) do
    %{
      result
      | data_points: [data_point | result.data_points],
        is_position_open: position_open?(action),
        trades_count: calculate_trade_count(result, action)
    }
  end

  @spec compile(result :: %__MODULE__{}, options :: keyword()) :: %__MODULE__{}
  def compile(result, options \\ [])

  def compile(result, _options) do
    trade_stats =
      result
      |> close_maybe_dangling_open_trade()
      |> CompilePairs.call!()
      |> calculate_trade_stats!()

    Enum.into(trade_stats, result)
  end

  @doc """
  Returns a comprehensive summary of all statistics as a map.

  This provides a clean view of all calculated metrics without the internal
  data structures like data_points and trade_pairs.
  """
  @spec comprehensive_summary(result :: %__MODULE__{}) :: map()
  def comprehensive_summary(result) do
    %{
      # Basic metrics
      starting_balance: result.starting_balance,
      final_balance: result.starting_balance + result.total_profit_and_loss,
      total_profit_and_loss: result.total_profit_and_loss,
      total_return_pct: result.total_return_pct,
      duration_days: result.duration,
      trades_count: result.trades_count,

      # Return metrics
      cagr_pct: result.cagr_pct,

      # Risk metrics
      sharpe_ratio: result.sharpe_ratio,
      sortino_ratio: result.sortino_ratio,
      calmar_ratio: result.calmar_ratio,
      annual_volatility: result.annual_volatility,
      max_drawdown_pct: result.max_draw_down_percentage,
      max_drawdown_duration_days: result.max_draw_down_duration,
      average_drawdown_pct: result.average_draw_down_percentage,
      average_drawdown_duration_days: result.average_draw_down_duration,

      # Trading metrics
      win_rate: result.win_rate,
      win_count: result.win_count,
      profit_factor: result.profit_factor,
      expectancy: result.expectancy,
      expectancy_pct: result.expectancy_pct,

      # Trade analysis
      best_trade_pct: result.best_trade_by_percentage,
      worst_trade_pct: result.worst_trade_by_percentage,
      average_trade_pct: result.average_trade_by_percentage,
      max_trade_duration_days: result.max_trade_duration,
      average_trade_duration_days: result.average_trade_duration,

      # Profit/Loss breakdown
      gross_profit: result.gross_profit,
      gross_loss: result.gross_loss,
      average_winning_trade: result.average_winning_trade,
      average_losing_trade: result.average_losing_trade,
      largest_winning_trade: result.largest_winning_trade,
      largest_losing_trade: result.largest_losing_trade,

      # System quality
      sqn: result.sqn,
      sqn_interpretation: result.sqn_interpretation,

      # Position sizing
      kelly_criterion: result.kelly_criterion,
      kelly_interpretation: result.kelly_interpretation,

      # Market risk
      alpha: result.alpha,
      beta: result.beta,
      information_ratio: result.information_ratio,
      tracking_error: result.tracking_error,
      market_correlation: result.market_correlation
    }
  end

  @spec add_data_point?(result :: %__MODULE__{}, action :: ExPostFacto.action()) :: boolean()
  defp add_data_point?(%{is_position_open: true}, :close_buy), do: true
  defp add_data_point?(%{is_position_open: true}, :close_sell), do: true
  defp add_data_point?(%{is_position_open: true}, _), do: false
  defp add_data_point?(%{is_position_open: false}, :close_buy), do: false
  defp add_data_point?(%{is_position_open: false}, :close_sell), do: false
  defp add_data_point?(%{is_position_open: false}, _), do: true

  @spec position_open?(action :: ExPostFacto.action()) :: boolean()
  defp position_open?(:close_buy), do: false
  defp position_open?(:close_sell), do: false
  defp position_open?(_), do: true

  @spec calculate_trade_stats!(result :: %__MODULE__{}) :: keyword() | no_return()
  defp calculate_trade_stats!(result) do
    # Calculate performance-critical metrics concurrently
    concurrent_metrics = [
      {:drawdown_metrics, fn -> DrawDown.call!(result) end},
      {:profit_metrics, fn -> ProfitMetrics.gross_profit_and_loss(result) end},
      {:sqn_value, fn -> SystemQuality.system_quality_number(result) end},
      {:kelly_value, fn -> KellyCriterion.kelly_criterion(result) end}
    ]

    # Execute concurrent calculations
    concurrent_results =
      concurrent_metrics
      |> Task.async_stream(
        fn {key, fun} -> {key, fun.()} end,
        max_concurrency: System.schedulers_online(),
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.into(%{})

    # Extract concurrent results
    %{
      average_percentage: average_draw_down_percentage,
      max_percentage: max_draw_down_percentage,
      average_duration: average_draw_down_duration,
      max_duration: max_draw_down_duration
    } = concurrent_results.drawdown_metrics

    {gross_profit, gross_loss} = concurrent_results.profit_metrics
    sqn_value = concurrent_results.sqn_value
    kelly_value = concurrent_results.kelly_value

    # Estimate market metrics (using S&P 500 as default benchmark)
    # These could be made configurable in the future
    # Typical S&P 500 annual return
    benchmark_return = 10.0
    # Typical risk-free rate
    risk_free_rate = 0.02

    # Group remaining metrics by computational cost for potential future optimization
    basic_metrics = [
      {:trade_pairs, result.trade_pairs},
      {:total_profit_and_loss, TotalProfitAndLoss.calculate!(result.data_points, 0.0)},
      {:win_rate, WinRate.calculate!(result)},
      {:win_count, WinRate.calculate_win_count!(result.trade_pairs)}
    ]

    trade_metrics = [
      {:best_trade_by_percentage, TradePercentage.best!(result)},
      {:worst_trade_by_percentage, TradePercentage.worst!(result)},
      {:average_trade_by_percentage, TradePercentage.average!(result)},
      {:max_trade_duration, TradeDuration.max!(result)},
      {:average_trade_duration, TradeDuration.average!(result)}
    ]

    drawdown_metrics = [
      {:average_draw_down_percentage, average_draw_down_percentage},
      {:max_draw_down_percentage, max_draw_down_percentage},
      {:max_draw_down_duration, max_draw_down_duration},
      {:average_draw_down_duration, average_draw_down_duration}
    ]

    # Financial ratios could be computed concurrently in the future if they become expensive
    financial_metrics = [
      {:total_return_pct, FinancialRatios.total_return_percentage(result)},
      {:cagr_pct, FinancialRatios.annual_return_percentage(result)},
      {:sharpe_ratio, FinancialRatios.sharpe_ratio(result, risk_free_rate)},
      {:sortino_ratio, FinancialRatios.sortino_ratio(result, risk_free_rate)},
      {:calmar_ratio, FinancialRatios.calmar_ratio(result)},
      {:annual_volatility, FinancialRatios.annual_volatility(result)}
    ]

    profit_metrics = [
      {:profit_factor, ProfitMetrics.profit_factor(result)},
      {:expectancy, ProfitMetrics.expectancy(result)},
      {:expectancy_pct, ProfitMetrics.expectancy_percentage(result)},
      {:gross_profit, gross_profit},
      {:gross_loss, gross_loss},
      {:average_winning_trade, ProfitMetrics.average_winning_trade(result)},
      {:average_losing_trade, ProfitMetrics.average_losing_trade(result)},
      {:largest_winning_trade, ProfitMetrics.largest_winning_trade(result)},
      {:largest_losing_trade, ProfitMetrics.largest_losing_trade(result)}
    ]

    system_quality_metrics = [
      {:sqn, sqn_value},
      {:sqn_interpretation, SystemQuality.sqn_interpretation(sqn_value)}
    ]

    kelly_metrics = [
      {:kelly_criterion, kelly_value},
      {:kelly_interpretation, KellyCriterion.kelly_interpretation(kelly_value)}
    ]

    market_risk_metrics = [
      {:alpha, MarketRisk.alpha(result, benchmark_return, risk_free_rate)},
      {:beta, MarketRisk.beta(result, benchmark_return, risk_free_rate)},
      {:information_ratio,
       MarketRisk.information_ratio(result, benchmark_return, risk_free_rate)},
      {:tracking_error, MarketRisk.tracking_error(result, benchmark_return)},
      {:market_correlation, MarketRisk.market_correlation(result)}
    ]

    # Combine all metrics efficiently
    basic_metrics ++
      trade_metrics ++
      drawdown_metrics ++
      financial_metrics ++
      profit_metrics ++
      system_quality_metrics ++
      kelly_metrics ++
      market_risk_metrics
  end

  defp calculate_trade_count(result, :close_buy), do: result.trades_count + 1
  defp calculate_trade_count(result, :close_sell), do: result.trades_count + 1
  defp calculate_trade_count(result, _), do: result.trades_count

  defmodule ResultCalculationError, do: defexception(message: "Error calculating result")

  defimpl Collectable, for: ExPostFacto.Result do
    @spec into(result :: struct()) :: {struct(), (any(), :done | :halt | {any(), any()} -> any())}
    def into(result) do
      collector_fun = fn
        result_struct, {:cont, {k, v}} ->
          Map.replace(result_struct, k, v)

        result_struct, :done ->
          result_struct

        _result_struct, :halt ->
          :ok
      end

      initial_acc = result

      {initial_acc, collector_fun}
    end
  end

  @spec close_maybe_dangling_open_trade(result :: %__MODULE__{}) :: %__MODULE__{}
  defp close_maybe_dangling_open_trade(
         %{data_points: [%{datum: datum, action: :buy, index: index} = dangler | rest]} = result
       ) do
    %{
      result
      | data_points: [
          %DataPoint{datum: datum, action: :close_buy, index: index + 1},
          dangler | rest
        ],
        trades_count: result.trades_count + 1
    }
  end

  defp close_maybe_dangling_open_trade(
         %{data_points: [%{datum: datum, action: :sell, index: index} = dangler | rest]} = result
       ) do
    %{
      result
      | data_points: [
          %DataPoint{datum: datum, action: :close_sell, index: index + 1},
          dangler | rest
        ],
        trades_count: result.trades_count + 1
    }
  end

  defp close_maybe_dangling_open_trade(result), do: result
end
