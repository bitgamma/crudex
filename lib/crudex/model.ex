defmodule Crudex.Model do
  
  ## Macros
  defmacro __using__(_) do
    quote do
      use Ecto.Model

      defimpl Poison.Encoder, for: __MODULE__ do
        def encode(model, options), do: Crudex.Model.encode(model, @for) |> Poison.Encoder.Map.encode(options)
      end

      def decode(model), do: Crudex.Model.decode(model, __MODULE__)
    end
  end

  ## Public API
  def encoded_binary(id), do: Base.url_encode64(id)
  def decoded_binary(id), do: Base.url_decode64!(id)

  def encode(model, module) do
    model
    |> Map.from_struct
    |> encode_model_associations(module)
    |> encode_fields(module)
  end

  def decode(model, module) do
    struct(module, _decode(model, module))
  end

  ## Implementation
  defp encode_model_associations(model, module) do
    reduce_on_associations(model, module, fn field, model ->
      {v, model} = Dict.pop(model, field)
      Dict.put(model, field, fetch_association(v))
    end)
  end

  defp encode_fields(model, module), do: reduce_on_existing_fields(model, module, &encode_field/2)
  defp encode_field(:datetime, field_val) do
    field_val
    |> Ecto.DateTime.to_erl
    |> Timex.Date.from
    |> Timex.DateFormat.format!("{ISOz}")
  end
  defp encode_field(_, nil), do: nil
  defp encode_field(:uuid, field_val), do: encoded_binary(field_val)
  defp encode_field(:binary, field_val), do: encoded_binary(field_val)
  defp encode_field(_type, field_val), do: field_val

  defp fetch_association(%Ecto.Associations.NotLoaded{}), do: %{loaded: false}
  defp fetch_association(assoc), do: assoc

  defp _decode(model, module) do
    model
    |> convert_keys_to_atoms
    |> decode_model_associations(module)
    |> decode_fields(module)
  end

  def convert_keys_to_atoms(model) do
    for {k, v} <- model, do: {convert_key(k), v}, into: Map.new
  end

  defp convert_key(k) when is_atom(k), do: k
  defp convert_key(k) when is_binary(k), do: String.to_existing_atom(k)

  defp decode_fields(model, module), do: reduce_on_existing_fields(model, module, &decode_field/2)

  defp decode_field(:datetime, field_val) do
    field_val |> Timex.DateFormat.parse!("{ISOz}") |> Timex.Date.Convert.to_erlang_datetime |> Ecto.DateTime.from_erl 
  end
  defp decode_field(_, nil), do: nil
  defp decode_field(:uuid, field_val), do: decoded_binary(field_val)
  defp decode_field(:binary, field_val), do: decoded_binary(field_val)
  defp decode_field(_type, field_val), do: field_val

  defp decode_model_associations(model, module) do
    reduce_on_associations(model, module, &Dict.delete(&2, &1))
  end

  ## Utils
  defp reduce_on_associations(model, module, fun), do: Enum.reduce(module.__schema__(:associations), model, fun)
  defp reduce_on_fields(model, module, fun), do: Enum.reduce(module.__schema__(:fields), model, fun)
  defp reduce_on_existing_fields(model, module, fun), do: reduce_on_fields(model, module, &apply_on_existing_field(&1, &2, module, fun))
  defp apply_on_existing_field(field, model, module, fun) do
    if Dict.has_key?(model, field) do
      decoded_field = fun.(module.__schema__(:field, field), model[field])
      Dict.put(model, field, decoded_field)
    else
      model
    end
  end
end