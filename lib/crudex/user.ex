defmodule Crudex.User do
  use Crudex.Model

  crudex_schema "users" do 
    field :display_name, :string   
    field :email, :string
    field :salt, :binary
    field :password, :binary
    field :role, :string
  end

  validate recipe,
    email: present(message: "must be present"),
    salt: present(message: "must be present"),
    password: present(message: "must be present"),
    role: present(message: "must be present")
end