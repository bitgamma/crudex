defmodule Crudex.JSONDateTime do
  def type, do: :datetime

  def cast(string) when is_binary(string) do
    case Timex.DateFormat.parse(string, "{ISOz}") do
      {:ok, date} -> date
      :error -> :error
    end
  end
  def cast(%Timex.DateTime{} = dt), do: dt
  def cast(_), do: :error

  def blank?(nil), do: true
  def blank?(_), do: false

  def load({{_, _, _}, {_, _, _}} = dt), do: {:ok,  dt |> Timex.Date.from}
  def load(_), do: :error

  def dump(%Timex.DateTime{} = dt), do: {:ok, dt |> Timex.Date.Convert.to_erlang_datetime}
  def dump(_), do: :error
end