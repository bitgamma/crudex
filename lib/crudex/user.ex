defmodule Crudex.User do
  use Crudex.Model

  crudex_schema "users" do 
    field :display_name, :string   
    field :email, :string
    hidden_field :salt, Crudex.JSONBinary
    hidden_field :password, Crudex.JSONBinary
    field :role, :string
  end

  def changeset(user, params) do
    params
    |> cast(user, ~w(email salt password role), ~w(display_name id created_at updated_at))
    |> validate_format(:email, ~r/@/)
    |> validate_unique(:email)
  end
end