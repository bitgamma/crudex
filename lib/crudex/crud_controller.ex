defmodule Crudex.CrudController do
  use Phoenix.Controller
  import Ecto.Query, only: [from: 2]

  defmacro __using__(_) do
    quote do
      use Phoenix.Controller
      import Crudex.CrudController, only: [crud_for: 1, crud_for: 2, defcrud: 2, send_error: 3]  
      @user_scoped false    
    end
  end

  defmacro defcrud(module, action) do
    implementation = String.to_existing_atom("do_#{action}")

    quote do
      def unquote(action)(conn, params) do 
        apply(Crudex.CrudController, unquote(implementation), [conn, @ecto_repo, unquote(module), @user_scoped, params])
      end
    end
  end

  defmacro crud_for(module, actions \\ [:index, :create, :show, :update, :destroy]) do
    for action <- actions, do: quote do: defcrud(unquote(module), unquote(action))
  end

  def do_index(conn, repo, module, user_scoped, _) do
    json conn, module |> apply_scope(conn, user_scoped) |> repo.all
  end

  def do_create(conn, repo, module, user_scoped, %{"data" => data}) do
    data = data |> module.decode |> add_user_id(conn, user_scoped)

    case module.validate(data) do
      nil -> data |> repo.insert |> send_data(conn)
      errors -> send_error(conn, :bad_request, errors)
    end
  end

  def do_show(conn, repo, module, user_scoped, %{"id" => data_id}) when not is_nil(data_id) do
    assocs = module.__schema__(:associations) |> Enum.filter(&filter_assoc(&1, module))
    decoded_id = Crudex.Model.decoded_binary(data_id)

    case from(r in module, where: r.id == ^decoded_id, preload: ^assocs) |> apply_scope(conn, user_scoped) |> repo.one do
      nil -> send_error(conn, :not_found, %{message: "not found"})
      data -> send_data(data, conn)
    end 
  end
  def do_show(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :not_found, %{message: "not found"})

  def do_update(conn, repo, module, user_scoped, %{"id" => data_id, "data" => updated_fields}) when not is_nil(data_id) do
    decoded_id = Crudex.Model.decoded_binary(data_id)
    sanitized_fields = updated_fields |> Crudex.Model.convert_keys_to_atoms |> sanitize(user_scoped)
    case from(r in module, where: r.id == ^decoded_id) |> apply_scope(conn, user_scoped) |> repo.one do
      nil -> send_error(conn, :not_found, %{message: "not found"})
      data -> data |> struct(sanitized_fields) |> _update_data(conn, repo, module)
    end
  end
  def do_update(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :not_found, %{message: "not found"})

  def do_destroy(conn, repo, module, user_scoped, %{"id" => data_id}) when not is_nil(data_id) do
    decoded_id = Crudex.Model.decoded_binary(data_id)
    case from(r in module, where: r.id == ^decoded_id) |> apply_scope(conn, user_scoped) |> repo.delete_all do
      1 -> json conn, :ok
      0 -> send_error(conn, :not_found, %{message: "not found"})
    end
  end
  def do_destroy(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :not_found, %{message: "not found"})

  def send_error(conn, status, errors) do
    conn
    |> put_status(Plug.Conn.Status.code(status))
    |> json %{errors: errors}    
  end

  defp send_data(data, conn) do
    json conn, %{data: data}
  end 

  defp _update_data(data, conn, repo, module) do
    case module.validate(data) do
      nil -> data |> repo.update |> send_data(conn)
      errors -> send_error(conn, :bad_request, errors)
    end    
  end

  defp sanitize(data, user_scoped), do: data |> Map.delete(:id) |> delete_user_info(user_scoped)
  defp delete_user_info(data, true), do: Map.delete(data, :user_id)
  defp delete_user_info(data, false), do: data

  defp filter_assoc(field, module) do
    module.__schema__(:association, field).__struct__ != Ecto.Associations.BelongsTo
  end

  defp get_user_id(conn), do: conn.assigns[:authenticated_user] |> Map.get(:id)

  defp add_user_id(data, conn, true), do: Map.put(data, :user_id, get_user_id(conn))
  defp add_user_id(data, _conn, false), do: data

  defp apply_scope(query, _conn, false), do: query
  defp apply_scope(query, conn, true) do
    user_id = get_user_id(conn)
    from(r in query, where: r.user_id == ^user_id)
  end
end