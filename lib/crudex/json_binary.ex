defmodule Crudex.JSONBinary do
  def type, do: :binary

  def cast(string) when is_binary(string) do
    case Base.url_decode64(string) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:ok, string}
    end
  end
  def cast(_), do: :error

  def cast!(val) do
    case cast(val) do
      {:ok, uuid} -> uuid
      :error -> raise "Invalid binary format"
    end
  end

  def encode(binary) when is_binary(binary), do: Base.url_encode64(binary)

  def blank?(nil), do: true
  def blank?(<<>>), do: true
  def blank?(_), do: false

  def load(bin) when is_binary(bin), do: {:ok, bin}
  def load(_), do: :error

  def dump(bin) when is_binary(bin), do: {:ok, bin}
  def dump(_), do: :error
end