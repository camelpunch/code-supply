defmodule AffableWeb.UserConfirmationControllerTest do
  use AffableWeb.ConnCase, async: true
  use Bamboo.Test

  alias Affable.Accounts
  alias Affable.Repo
  import Affable.AccountsFixtures
  import Hammox
  import ExUnit.CaptureLog

  alias Affable.MockK8s

  setup :verify_on_exit!

  setup do
    %{user: unconfirmed_user_fixture()}
  end

  describe "GET /users/confirm" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.user_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /users/confirm" do
    setup do
      %{expected_subject: "Confirmation of your Affable account"}
    end

    test "sends a new confirmation token", %{
      conn: conn,
      user: user,
      expected_subject: expected_subject
    } do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "confirm"

      assert_email_delivered_with(
        to: [nil: user.email],
        subject: expected_subject
      )
    end

    test "does not send confirmation token if account is confirmed", %{
      conn: conn,
      user: user,
      expected_subject: expected_subject
    } do
      Repo.update!(Accounts.User.confirm_changeset(user))

      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      refute Repo.get_by(Accounts.UserToken, user_id: user.id)
      refute_email_delivered_with(subject: expected_subject)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.user_confirmation_path(conn, :create), %{
          "user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your e-mail is in our system"
      assert Repo.all(Accounts.UserToken) == []
    end
  end

  describe "GET /users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, user: user} do
      stub(MockK8s, :deploy, fn _ -> {:ok, ""} end)

      token = get_token(user)

      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == Routes.sites_path(conn, :index)
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Accounts.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Accounts.UserToken) == []

      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
    end

    test "deploys the site", %{conn: conn, user: user} do
      expect(MockK8s, :deploy, fn %{
                                    "apiVersion" => "site-operator.code.supply/v1",
                                    "kind" => "AffiliateSite",
                                    "metadata" => %{"name" => name},
                                    "spec" => %{"domains" => [domain_name]}
                                  } ->
        assert name =~ ~r/[a-z0-9]+/
        assert domain_name =~ ~r/.+\.affable\.app/
        {:ok, ""}
      end)

      assert get(conn, Routes.user_confirmation_path(conn, :confirm, get_token(user)))
             |> get_flash(:info) =~ "It should be ready"
    end

    @tag :capture_log
    test "shows a custom message if the site cannot be deployed", %{conn: conn, user: user} do
      stub(MockK8s, :deploy, fn _ -> {:error, "log this message"} end)

      refute get(conn, Routes.user_confirmation_path(conn, :confirm, get_token(user)))
             |> get_flash(:info) =~ "It should be ready"
    end

    test "logs if the site cannot be deployed", %{conn: conn, user: user} do
      stub(MockK8s, :deploy, fn _ -> {:error, "log this message"} end)

      assert capture_log(fn ->
               get(conn, Routes.user_confirmation_path(conn, :confirm, get_token(user)))
             end) =~ "log this message"
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
      refute Accounts.get_user!(user.id).confirmed_at
    end

    defp get_token(user) do
      extract_user_token(fn url ->
        Accounts.deliver_user_confirmation_instructions(user, url)
      end)
    end
  end
end
