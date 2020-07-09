defmodule Majic.MixProject do
  use Mix.Project

  if :erlang.system_info(:otp_release) < '21' do
    raise "Majic requires Erlang/OTP 21 or newer"
  end

  def project do
    [
      app: :majic,
      version: "1.0.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: warnings_as_errors(Mix.env())],
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_env: make_env(),
      package: package(),
      deps: deps(),
      dialyzer: dialyzer(),
      name: "Majic",
      description: "File introspection with libmagic",
      source_url: "https://github.com/hrefhref/majic",
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer do
    [
      plt_add_apps: [:mix, :iex, :ex_unit, :plug, :mime],
      flags: ~w(error_handling no_opaque race_conditions underspecs unmatched_returns)a,
      ignore_warnings: "dialyzer-ignore-warnings.exs",
      list_unused_filters: true
    ]
  end

  defp deps do
    [
      {:nimble_pool, "~> 0.1"},
      {:mime, "~> 1.0"},
      {:plug, "~> 1.0", optional: true},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:elixir_make, "~> 0.4", runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib/gen_magic/* src/*.c Makefile),
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/hrefhref/majic"},
      source_url: "https://github.com/hrefhref/majic"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp warnings_as_errors(:dev), do: false
  defp warnings_as_errors(_), do: true

  defp make_env() do
    otp = :erlang.system_info(:otp_release)
          |> to_string()
          |> String.to_integer()

    ei_incomplete = if(otp < 21.3, do: "YES", else: "NO")
    %{"EI_INCOMPLETE" => ei_incomplete}
  end

end
