defmodule AffableWeb.DashboardLiveTest do
  use AffableWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Affable.Accounts
  alias Affable.Accounts.User
  alias Affable.Sites

  describe "authenticated user" do
    setup context do
      register_and_log_in_user(context)
    end

    test "redirects to login page when token is bogus", %{conn: conn, user: user} do
      Accounts.delete_user(user)

      conn = get(conn, "/dashboard")
      assert html_response(conn, 302)

      expected_path = Routes.user_session_path(conn, :new)

      {:error, {:redirect, %{to: actual_path}}} = live(conn, path(conn))

      assert actual_path == expected_path
    end

    test "shows spinner until site is available", %{conn: conn, user: %User{sites: [site]} = user} do
      {:ok, view, html} = live(conn, path(conn))

      assert html =~ "pending"

      site_name = site.name

      Phoenix.PubSub.broadcast(:affable, site.internal_name, %{
        Sites.raw(site |> Affable.Repo.preload(:items))
        | made_available_at: DateTime.utc_now()
      })

      html = render(view)

      refute html =~ "pending"
      assert html =~ "available"
    end
  end

  describe "not authenticated" do
    test "redirects to login page", %{conn: conn} do
      conn = get(conn, "/dashboard")
      assert html_response(conn, 302)

      expected_path = Routes.user_session_path(conn, :new)

      {:error, {:redirect, %{to: actual_path}}} = live(conn, path(conn))

      assert actual_path == expected_path
    end
  end

  defp path(conn) do
    AffableWeb.Router.Helpers.dashboard_path(conn, :show)
  end
end
