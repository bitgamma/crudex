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

  defmacro crud_for(module, actions \\ [:index, :create, :show, :update, :delete]) do
    for action <- actions, do: quote do: defcrud(unquote(module), unquote(action))
  end

  def do_index(conn, repo, module, user_scoped, _) do
    json conn, module |> apply_scope(conn, user_scoped) |> repo.all
  end

  def do_create(conn, repo, module, user_scoped, %{"data" => data}) do
    changeset = module.changeset(struct(module), add_user_id(data, conn, user_scoped))

    case changeset.valid? do
      true -> changeset |> repo.insert |> send_data(conn)
      false -> send_error(conn, :bad_request, format_errors(changeset.errors))
    end
  end
  def do_create(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :bad_request, %{message: "bad request"})

  def do_show(conn, repo, module, user_scoped, %{"id" => data_id}) when not is_nil(data_id) do
    assocs = module.__schema__(:associations) |> Enum.filter(&filter_assoc(&1, module))

    case from(r in module, where: r.id == ^data_id, preload: ^assocs) |> apply_scope(conn, user_scoped) |> repo.one do
      nil -> send_error(conn, :not_found, %{message: "not found"})
      data -> data |> send_data(conn)
    end
  end
  def do_show(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :not_found, %{message: "not found"})

  def do_update(conn, repo, module, user_scoped, %{"id" => data_id, "data" => updated_fields}) when not is_nil(data_id) do
    sanitized_fields = sanitize(updated_fields, user_scoped)
    case from(r in module, where: r.id == ^data_id) |> apply_scope(conn, user_scoped) |> repo.one do
      nil -> send_error(conn, :not_found, %{message: "not found"})
      data -> data |> module.changeset(sanitized_fields) |> _update_data(conn, repo)
    end
  end
  def do_update(conn, _repo, _module, _user_scoped, %{"data" => _updated_fields}), do: send_error(conn, :not_found, %{message: "not found"})
  def do_update(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :bad_request, %{message: "bad request"})

  def do_delete(conn, repo, module, user_scoped, %{"id" => data_id}) when not is_nil(data_id) do
    case from(r in module, where: r.id == ^data_id) |> apply_scope(conn, user_scoped) |> repo.delete_all do
      1 -> json conn, %{status: "ok"}
      0 -> send_error(conn, :not_found, %{message: "not found"})
    end
  end
  def do_delete(conn, _repo, _module, _user_scoped, _params), do: send_error(conn, :not_found, %{message: "not found"})

  def send_error(conn, status, errors) do
    conn
    |> put_status(status)
    |> json %{errors: errors}
  end

  def send_data(data, conn) do
    json conn, %{data: data}
  end

  def apply_user_scope(query, conn) do
    apply_scope(query, conn, true)
  end

  defp _update_data(changeset, conn, repo) do
    case changeset.valid? do
      true -> changeset |> repo.update |> send_data(conn)
      false -> send_error(conn, :bad_request, format_errors(changeset.errors))
    end
  end

  defp sanitize(data, user_scoped), do: data |> Map.delete("id") |> delete_user_info(user_scoped)
  defp delete_user_info(data, true), do: Map.delete(data, "user_id")
  defp delete_user_info(data, false), do: data

  defp filter_assoc(field, module) do
    module.__schema__(:association, field).__struct__ != Ecto.Association.BelongsTo
  end

  def get_authenticated_user(conn), do: PlugAuth.Authentication.Utils.get_authenticated_user(conn) |> Map.get(:id) |> Ecto.UUID.cast |> elem(1)

  defp add_user_id(data, conn, true), do: Map.put(data, "user_id", get_authenticated_user(conn))
  defp add_user_id(data, _conn, false), do: data

  defp apply_scope(query, _conn, false), do: query
  defp apply_scope(query, conn, true) do
    user_id = get_authenticated_user(conn)
    from(r in query, where: r.user_id == ^user_id)
  end

  defp format_errors(errors), do: Enum.into(errors, Map.new)
end
