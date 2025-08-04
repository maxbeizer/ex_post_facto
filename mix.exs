defmodule ExPostFacto.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_post_facto,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ex_post_facto",
      source_url: "https://github.com/maxbeizer/ex_post_facto"
    ]
  end

  defp package do
    [
      name: "ex_post_facto",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["MIT"],
      description: "Backtesting in Elixir",
      links: %{"GitHub" => "https://github.com/maxbeizer/ex_post_facto"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
