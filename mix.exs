defmodule Crudex.Mixfile do
  use Mix.Project

  def project do
    [app: :crudex,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps, 
     package: package,
     description: description,
     docs: [readme: "README.md", main: "README"]]
  end

  def application do
    [applications: [:phoenix, :ecto, :timex, :plug_auth]]
  end

  defp deps do
    [
      {:phoenix, github: "phoenixframework/phoenix"},
      {:ecto, github: "elixir-lang/ecto"},
      {:timex, "~> 0.13.2"},
      {:plug_auth, ">= 0.0.0"},     
      {:earmark, "~> 0.1", only: :docs},
      {:ex_doc, "~> 0.6", only: :docs}
    ]
  end

  defp description do
    "A glue keeping Phoenix and Ecto together"
  end

  defp package do
    [contributors: ["Michele Balistreri"],
     licenses: ["ISC"],
     links: %{"GitHub" => "https://github.com/briksoftware/crudex"}]
  end
end
