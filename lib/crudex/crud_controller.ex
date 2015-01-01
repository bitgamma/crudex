defmodule Crudex.CrudController do
  use Phoenix.Controller
  import Ecto.Query, only: [from: 2]

  defmacro __using__(_) do
    quote do
      use Phoenix.Controller
      import Crudex.CrudController, only: [crud_for: 1, crud_for: 2, defcrud: 2, send_error: 3]      
    end
  end

  defmacro defcrud(module, action) do
    implementation = String.to_existing_atom("do_#{action}")
    quote do
      def unquote(action)(conn, params), do: apply(Crudex.CrudController, unquote(implementation), [conn, @ecto_repo, unquote(module), params])
    end
  end

  defmacro crud_for(module, actions \\ [:index, :create, :show, :update, :destroy]) do
    for action <- actions, do: quote do: defcrud(unquote(module), unquote(action))
  end

  def do_index(conn, repo, module, _) do
    json conn, repo.all(module)
  end

  def do_create(conn, repo, module, %{"data" => data}) do
    data = module.decode(data)

    case module.validate(data) do
      nil -> data |> repo.insert |> send_data(conn)
      errors -> send_error(conn, :bad_request, errors)
    end
  end

  def do_show(conn, repo, module, %{"id" => data_id}) do
    assocs = module.__schema__(:associations) |> Enum.filter(&filter_assoc(&1, module))
    decoded_id = Crudex.Model.decoded_binary(data_id)

    case repo.one from(r in module, where: r.id == ^decoded_id, preload: ^assocs) do
      nil -> send_error(conn, :not_found, %{message: "not found"})
      data -> send_data(data, conn)
    end 
  end

  def do_update(conn, repo, module, %{"id" => data_id, "data" => updated_fields}) do
    if data = repo.get(module, Crudex.Model.decoded_binary(data_id)) do
      data = struct(data, Crudex.Model.convert_keys_to_atoms(updated_fields))
      case module.validate(data) do
        nil -> data |> repo.update |> send_data(conn)
        errors -> send_error(conn, :bad_request, errors)
      end
    else
      send_error(conn, :not_found, %{message: "not found"})
    end
  end

  def do_destroy(conn, repo, module, %{"id" => data_id}) do
    decoded_id = Crudex.Model.decoded_binary(data_id)
    result = repo.delete_all from(r in module, where: r.id == ^decoded_id)

    if result == 1 do
      json conn, :ok
    else
      send_error(conn, :not_found, %{message: "not found"})
    end
  end

  def send_error(conn, status, errors) do
    conn
    |> put_status(Plug.Conn.Status.code(status))
    |> json %{errors: errors}    
  end

  defp send_data(data, conn) do
    json conn, %{data: data}
  end 

  defp filter_assoc(field, module) do
    module.__schema__(:association, field).__struct__ != Ecto.Associations.BelongsTo
  end
end