defmodule Crudex.Model do
  
  ## Macros
  defmacro __using__(_) do
    quote do
      use Ecto.Model
      import Crudex.Model, only: [crudex_schema: 2]

      defimpl Poison.Encoder, for: __MODULE__ do
        def encode(model, options), do: Crudex.Model.encode(model, @for) |> Poison.Encoder.Map.encode(options)
      end
    end
  end

  defmacro crudex_schema(schema_name, do: block) do
    quote do
      @primary_key {:id, Crudex.JSONUUID, []}
      @foreign_key_type Crudex.JSONUUID
      schema unquote(schema_name) do
        unquote(block)
        field :created_at, Crudex.JSONDateTime, default: Timex.Date.universal
        field :updated_at, Crudex.JSONDateTime, default: Timex.Date.universal
      end
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

  ## Implementation
  defp encode_model_associations(model, module) do
    reduce_on_associations(model, module, fn field, model ->
      {v, model} = Dict.pop(model, field)
      Dict.put(model, field, fetch_association(v))
    end)
  end

  defp encode_fields(model, module), do: reduce_on_existing_fields(model, module, &encode_field/2)
  
  defp encode_field(_, nil), do: nil
  defp encode_field(Crudex.JSONDateTime, field_val), do: Timex.DateFormat.format!(field_val, "{ISOz}")
  defp encode_field(Crudex.JSONUUID, field_val), do: encoded_binary(field_val)
  defp encode_field(Crudex.JSONBinary, field_val), do: encoded_binary(field_val)
  defp encode_field(_type, field_val), do: field_val

  defp fetch_association(%Ecto.Associations.NotLoaded{}), do: nil
  defp fetch_association(assoc), do: assoc

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