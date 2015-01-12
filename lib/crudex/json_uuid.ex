defmodule Crudex.JSONUUID do
  def type, do: :uuid

  def cast(<< u0::64, ?-, u1::32, ?-, u2::32, ?-, u3::32, ?-, u4::96 >>) do
    Base.decode16(<< u0::64, u1::32, u2::32, u3::32, u4::96 >>, case: :mixed)
  end
  def cast(uuid = << _::128 >>), do: {:ok, uuid}
  def cast(_), do: :error

  def cast!(val) do
    case cast(val) do
      {:ok, uuid} -> uuid
      :error -> raise "Invalid UUID format"
    end
  end

  def encode(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    :io_lib.format("~8.16.0B-~4.16.0B-~4.16.0B-~4.16.0B-~12.16.0B", [u0, u1, u2, u3, u4]) |> to_string
  end
  def blank?(nil), do: true
  def blank?(<<>>), do: true
  def blank?(_), do: false

  def load(bin) when is_binary(bin), do: {:ok, bin}
  def load(_), do: :error

  def dump(bin) when is_binary(bin), do: {:ok, bin}
  def dump(_), do: :error
end