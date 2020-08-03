defmodule Affable.DomainsTest do
  use Affable.DataCase

  alias Affable.Domains

  describe "domains" do
    alias Affable.Domains.Domain
    import Affable.AccountsFixtures

    @valid_attrs %{name: "somename.com"}
    @update_attrs %{name: "someupdatedname.com"}
    @invalid_attrs %{name: nil}

    setup do
      %{user: user_fixture()}
    end

    def domain_fixture(user, attrs \\ %{}) do
      {:ok, domain} =
        Domains.create_domain(
          user,
          attrs
          |> Enum.into(@valid_attrs)
        )

      domain
    end

    test "list_domains/1 returns all domains for a user (reverse creation order)", %{user: user} do
      foo = domain_fixture(user, name: "foo.com")
      another_user = user_fixture()
      bar = domain_fixture(another_user, name: "bar.com")
      baz = domain_fixture(another_user, name: "baz.com")

      assert Domains.list_domains(user) == [foo]
      assert Domains.list_domains(another_user) == [baz, bar]
    end

    test "get_domain!/2 returns the domain with given id", %{user: user} do
      domain = domain_fixture(user)
      assert Domains.get_domain!(user, domain.id) == domain
    end

    test "get_domain!/2 fails if user doesn't own the domain", %{user: user} do
      domain = domain_fixture(user)

      assert_raise(Ecto.NoResultsError, fn ->
        Domains.get_domain!(user_fixture(), domain.id) == domain
      end)
    end

    test "create_domain/2 with valid data creates a domain", %{user: user} do
      assert {:ok, %Domain{} = domain} = Domains.create_domain(user, @valid_attrs)
      assert domain.name == "somename.com"
    end

    test "create_domain/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Domains.create_domain(user, @invalid_attrs)
    end

    test "update_domain/2 with valid data updates the domain", %{user: user} do
      domain = domain_fixture(user)
      assert {:ok, %Domain{} = domain} = Domains.update_domain(domain, @update_attrs)
      assert domain.name == "someupdatedname.com"
    end

    test "update_domain/2 with invalid data returns error changeset", %{user: user} do
      domain = domain_fixture(user)
      assert {:error, %Ecto.Changeset{}} = Domains.update_domain(domain, @invalid_attrs)
      assert domain == Domains.get_domain!(user, domain.id)
    end

    test "delete_domain/1 deletes the domain", %{user: user} do
      domain = domain_fixture(user)
      assert {:ok, %Domain{}} = Domains.delete_domain(domain)
      assert_raise Ecto.NoResultsError, fn -> Domains.get_domain!(user, domain.id) end
    end

    test "change_domain/1 returns a domain changeset", %{user: user} do
      domain = domain_fixture(user)
      assert %Ecto.Changeset{} = Domains.change_domain(domain)
    end
  end
end
