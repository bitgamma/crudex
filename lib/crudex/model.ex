defmodule Crudex.Model do
  
  ## Macros
  defmacro __using__(_) do
    quote do
      use Ecto.Model
      import Crudex.Model, only: [crudex_schema: 2, virtual_field: 2]

      Module.register_attribute __MODULE__, :crudex_virtuals, accumulate: true, persist: false

      defimpl Poison.Encoder, for: __MODULE__ do
        def encode(model, options), do: Crudex.Model.encode(model, @for) |> Poison.Encoder.Map.encode(options)
      end
    end
  end

  defmacro crudex_schema(schema_name, do: block) do
    quote do
      @primary_key {:id, Crudex.JSONUUID, []}
      @foreign_key_type Crudex.JSONUUID
      @timestamps_type Crudex.JSONDateTime
      schema unquote(schema_name) do
        unquote(block)
        timestamps inserted_at: :created_at
      end

      def __crudex_virtuals__(:fields) do
        @crudex_virtuals
      end
    end
  end

  defmacro virtual_field(name, type) do
    quote do
      Module.put_attribute __MODULE__, :crudex_virtuals, {unquote(name), unquote(type)}
      field unquote(name), unquote(type), virtual: true
    end
  end

  ## Public API
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
  defp encode_field(Crudex.JSONDateTime, field_val), do: Crudex.JSONDateTime.encode(field_val)
  defp encode_field(Crudex.JSONUUID, field_val), do: Crudex.JSONUUID.encode(field_val)
  defp encode_field(Crudex.JSONBinary, field_val), do: Crudex.JSONBinary.encode(field_val)
  defp encode_field(_type, field_val), do: field_val

  defp fetch_association(%Ecto.Associations.NotLoaded{}), do: nil
  defp fetch_association(assoc), do: assoc

  ## Utils
  defp reduce_on_associations(model, module, fun), do: Enum.reduce(module.__schema__(:associations), model, fun)
  defp reduce_on_fields(model, module, fun), do: Enum.reduce(module.__changeset__, model, fun)
  defp reduce_on_existing_fields(model, module, fun), do: reduce_on_fields(model, module, &apply_on_existing_field(&1, &2, fun))
  defp apply_on_existing_field({field, type}, model, fun) do
    if Dict.has_key?(model, field) do
      decoded_field = fun.(type, model[field])
      Dict.put(model, field, decoded_field)
    else
      model
    end
  end
end