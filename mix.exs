defmodule ExPostFacto.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_post_facto,
      version: "0.2.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "ex_post_facto",
      source_url: "https://github.com/maxbeizer/ex_post_facto"
    ]
  end

  defp package do
    [
      name: "ex_post_facto",
      files: ~w(lib docs .formatter.exs mix.exs README* LICENSE* CHANGELOG* CONTRIBUTING*),
      licenses: ["MIT"],
      description: "Backtesting in Elixir",
      links: %{"GitHub" => "https://github.com/maxbeizer/ex_post_facto"}
    ]
  end

  defp docs do
    [
      main: "ExPostFacto",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "docs/GETTING_STARTED.md",
        "docs/API_REFERENCE.md",
        "docs/STRATEGY_API.md",
        "docs/INDICATORS.md",
        "docs/OPTIMIZATION.md",
        "docs/ADVANCED_TUTORIAL.md",
        "docs/BEST_PRACTICES.md",
        "docs/COMPREHENSIVE_METRICS.md",
        "docs/ENHANCED_DATA_HANDLING_EXAMPLES.md",
        "docs/ENHANCED_ERROR_HANDLING_SUMMARY.md",
        "docs/LIVEBOOK_INTEGRATION.md",
        "docs/MIGRATION_GUIDE.md",
        "docs/TROUBLESHOOTING.md"
      ],
      groups_for_extras: [
        "Getting Started": [
          "docs/GETTING_STARTED.md",
          "docs/API_REFERENCE.md"
        ],
        "Strategy Development": [
          "docs/STRATEGY_API.md",
          "docs/INDICATORS.md",
          "docs/ADVANCED_TUTORIAL.md"
        ],
        "Optimization & Analysis": [
          "docs/OPTIMIZATION.md",
          "docs/COMPREHENSIVE_METRICS.md"
        ],
        "Best Practices & Guides": [
          "docs/BEST_PRACTICES.md",
          "docs/ENHANCED_DATA_HANDLING_EXAMPLES.md",
          "docs/ENHANCED_ERROR_HANDLING_SUMMARY.md"
        ],
        "Integration & Migration": [
          "docs/LIVEBOOK_INTEGRATION.md",
          "docs/MIGRATION_GUIDE.md"
        ],
        Troubleshooting: [
          "docs/TROUBLESHOOTING.md"
        ],
        "Project Info": [
          "CHANGELOG.md",
          "CONTRIBUTING.md"
        ]
      ],
      source_ref: "v0.2.0",
      source_url: "https://github.com/maxbeizer/ex_post_facto"
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
