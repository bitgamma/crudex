# Crudex

A glue keeping Phoenix and Ecto together. It has the following features:

* JSON-encoding/decoding of Ecto models
* Dynamic virtual fields for models
* Simplifies creation of CRUD controllers
* User controller for login.

## Crudex.Model

By using the Crudex.Model module, like this:

```elixir
defmodule MyModel do
  use Crudex.Model
end
```

You make your model JSON-encodable using Poison. You should also use `Ecto.UUID`, `Crudex.JSONBinary`, `Ecto.DateTime` instead of `:uuid`, `:binary`, and `:datetime` in your model respectively.

The Crudex.Model also provides the following macros:

* `crudex_schema` => is like `schema` from Ecto.Model but defines ID/foreign keys to be UUID and creates timestamps. You should use this if you want to use the CRUD controller functionalities. It also allows using the two macros below
* `virtual_field` => creates a virtual field, which value will be resolved during encoding, by invoking a callback.
* `hidden_field` => creates a regular field which will be excluded when encoding

### Example
```elixir
defmodule Example.User do
  use Crudex.Model

  crudex_schema "users" do 
    field :name, :string   
    field :surname, :string   
    virtual_field :full_name, :string
    field :email, :string
    hidden_field :salt, Crudex.JSONBinary
    hidden_field :password, Crudex.JSONBinary
    field :role, :string
  end
  
  def __crudex_virtuals__(:resolve, :full_name, %{name: name, surname: surname}), do: name <> " " <> surname
  
  ...
end
```

## Crudex.CrudController

Allows automatic creation of complete or partial CRUD controllers. It even supports user scoping, assuming your model has a `user_id` field.

It has two macros

* `crud_for` => creates CRUD actions for the given model. Optionally you can specify which actions should be created.
* `defcrud` => defines a single CRUD action for the given model.

### Example

```elixir
defmodule BookController do
  use Crudex.CrudController

  plug PlugAuth.Authentication.Token, [source: :params, param: "auth_token"]
  plug :action

  @ecto_repo MyRepo
  @user_scoped true
  crud_for(Book)
end
```

Assuming you have a `Book` model, you will get the `:index, :create, :show, :update, :delete` actions created for you. Since `@user_scoped` is set to `true`, all actions will only be applicable for the user currently logged in. This works best in conjunction with plug_auth.

## Crudex.UserController
Provides a macro, `user_controller` to define a simple user controller. Access control should happen in the controller invoking this macro, using for example plug_auth. It is not very flexible for now, and is more there to show you how to do a complex controller with Crudex.

## TODO
There is a lot to do, pagination and filtering is one of the first things. Tests are missing although I have tests in the projects where I use this. Documentation in the code is also missing for now.

## LICENSE
Copyright (c) 2014, Michele Balistreri <michele@briksoftware.com>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
