defmodule Crudex.User do
  use Crudex.Model

  defmacro __using__(_) do
    quote do
      use Crudex.Model
      import Crudex.User, only: [user_schema: 2]
    end
  end

  defmacro user_schema(name, do: block) do
    quote do
      crudex_schema unquote(name) do
        field :email, :string
        hidden_field :salt, Crudex.JSONBinary
        hidden_field :password, Crudex.JSONBinary
        field :role, :string
        unquote(block)       
      end
    end
  end
end