defmodule Crudex.UserController do
  defmacro __using__(_) do
    quote do
      use Crudex.CrudController
      import Ecto.Query, only: [from: 2]
      import Crudex.UserController, only: [user_controller: 0]
    end
  end

  defmacro user_controller() do
    quote do
      crud_for(Crudex.User, [:index, :destroy])

      def sign_in(conn, %{"email" => email, "password" => password}) do
        case @ecto_repo.all from(u in Crudex.User, where: u.email == ^email) do
          [user | _] -> verify_secret(user.salt, user.password, password) |> do_sign_in(conn, user)
          _ -> do_sign_in(false, conn, nil)
        end
      end

      def sign_out(conn, %{"auth_token" => token}) do
        PlugAuth.Authentication.Token.remove_credentials(token)
        json conn, %{status: :ok}
      end

      def create(conn, %{"data" => user}) do
        Crudex.CrudController.do_create(conn, @ecto_repo, Crudex.User, false, %{"data" => convert_user_data(user)})
      end

      def update(conn, params = %{"data" => user}) do
        data_id = get_user_id(conn, params)
        Crudex.CrudController.do_update(conn, @ecto_repo, Crudex.User, false, %{"id" => data_id, "data" => convert_user_data(user)})
      end

      def show(conn, params) do
        data_id = get_user_id(conn, params)
        Crudex.CrudController.do_show(conn, @ecto_repo, Crudex.User, false, %{"id" => data_id})
      end

      defp get_user_id(%Plug.Conn{assigns: %{authenticated_user: %{role: "admin"}}}, %{"id" => data_id}), do: data_id
      defp get_user_id(conn, %{"id" => data_id}) do
        case get_authenticated_user(conn) do
          ^data_id -> data_id
          _ -> nil
        end
      end
      defp get_user_id(conn, _params), do: get_authenticated_user(conn)

      defp get_authenticated_user(conn), do: PlugAuth.Authentication.Utils.get_authenticated_user(conn) |> Map.get(:id) |> Crudex.Model.encoded_binary

      defp do_sign_in(true, conn, user) do
        token = PlugAuth.Authentication.Token.generate_token 
        PlugAuth.Authentication.Token.add_credentials(token, %{id: user.id, role: user.role})
        json conn, %{auth_token: token}
      end

      defp do_sign_in(false, conn, _user), do: send_error(conn, :unauthorized, %{message: "unauthorized"})

      defp verify_secret(salt, key, password) do
        Plug.Crypto.KeyGenerator.generate(password, salt)
        |> Plug.Crypto.secure_compare(key)
      end

      defp convert_user_data(user) do
        Dict.pop(user, "password")
        |> password_to_key
      end

      defp password_to_key({nil, user}), do: user
      defp password_to_key({pass, user}) do
        {salt, key} = generate_key(pass)

        user
        |> Dict.put("salt", Crudex.Model.encoded_binary(salt))
        |> Dict.put("password", Crudex.Model.encoded_binary(key))
      end

      defp generate_key(password) do
        salt = :crypto.strong_rand_bytes(32)
        {salt, Plug.Crypto.KeyGenerator.generate(password, salt)}
      end
    end
  end
end