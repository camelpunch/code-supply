defmodule Affable.SitesTest do
  use Affable.DataCase

  import Affable.{AccountsFixtures, SitesFixtures}

  alias Affable.Sites
  alias Affable.Sites.{Site, SiteMember, Item}
  alias Affable.Domains.Domain

  describe "sites" do
    alias Affable.Sites.Site

    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil}

    setup do
      Hammox.protect(
        Sites,
        Affable.SiteClusterIO,
        get_raw_site: 1,
        set_available: 2
      )
    end

    test "status of new site is pending" do
      assert %Site{}
             |> Sites.status() == :pending
    end

    test "canonical URL with a single domain uses that domain" do
      assert %Site{domains: [%Domain{name: "something.affable.app"}]}
             |> Sites.canonical_url() ==
               "https://something.affable.app/"
    end

    test "canonical URL with a custom domain is the custom domain" do
      assert %Site{
               domains: [
                 %Domain{name: "something.affable.app"},
                 %Domain{name: "my.domain.example.com"}
               ]
             }
             |> Sites.canonical_url() ==
               "https://my.domain.example.com/"
    end

    test "status of site that's been made available once is available, and doesn't update date subsequently",
         %{
           set_available_2: set_available
         } do
      site = site_fixture()

      first_made_available_at = DateTime.from_unix!(0)

      {:ok, site} = set_available.(site.id, first_made_available_at)

      assert site |> Sites.status() == :available

      {:ok, site} = set_available.(site.id, DateTime.from_unix!(1))
      assert site.made_available_at == first_made_available_at
    end

    test "get_site!/2 returns the site with given user id and id" do
      user = user_fixture()
      site = site_fixture(user)
      assert Sites.get_site!(user, site.id) == site
    end

    test "get_site!/2 fails if user is incorrect" do
      user = user_fixture()
      site = site_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Sites.get_site!(user, site.id)
      end
    end

    test "can fetch an untyped representation of the site, for distribution", %{
      get_raw_site_1: get_raw_site
    } do
      site = site_fixture()

      {:ok,
       %{
         name: "Top 10 Apples",
         items: [item | _rest] = items
       }} = get_raw_site.(site.id)

      assert length(items) == 10

      assert item.name == "Golden Delicious"

      assert Map.keys(item) == [
               :description,
               :image_url,
               :name,
               :position,
               :price,
               :url
             ]
    end

    test "returns error when untyped representation isn't available", %{
      get_raw_site_1: get_raw_site
    } do
      {:error, :not_found} = get_raw_site.(8_675_309)
    end

    test "new sites have a name, internal name, member, default domain and items" do
      user = user_fixture()
      site = site_fixture(user, %{name: "some name !@#!@#$@#%#$"})

      [%SiteMember{user_id: received_user_id}] = site.members
      [%Domain{name: domain_name}] = site.domains

      assert site.name == "some name !@#!@#$@#%#$"
      assert site.internal_name =~ ~r/site[a-z0-9]+/
      assert domain_name == "#{site.internal_name}.affable.app"
      assert received_user_id == user.id

      assert [%Item{name: "Golden Delicious"} | rest] = site.items
      assert length(rest) == 9
    end

    test "create_site/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sites.create_site(user_fixture(), @invalid_attrs)
    end

    test "can demote an item" do
      site = site_fixture()
      [first_before | rest] = site.items
      [second_before | _] = rest

      assert first_before.position == 1
      assert second_before.position == 2

      {:ok, site} = Sites.demote_item(site, "#{first_before.id}")

      [first_after | rest] = site.items
      [second_after | _] = rest

      assert first_after.position == 1
      assert second_after.position == 2

      assert first_after.name == second_before.name
      assert second_after.name == first_before.name
    end

    test "demoting at the last position doesn't increase position number" do
      site = site_fixture()
      item = site.items |> List.last()

      assert item.position == 10

      {:ok, site} = Sites.demote_item(site, "#{item.id}")

      item_after = site.items |> List.last()

      assert item_after.position == 10
    end

    test "can promote an item" do
      site = site_fixture()
      [first_before | rest] = site.items
      [second_before | _] = rest

      assert first_before.position == 1
      assert second_before.position == 2

      {:ok, site} = Sites.promote_item(site, "#{second_before.id}")

      [first_after | rest] = site.items
      [second_after | _] = rest

      assert first_after.position == 1
      assert second_after.position == 2

      assert first_after.name == second_before.name
      assert second_after.name == first_before.name
    end

    test "promoting at the first position doesn't decrease position number" do
      site = site_fixture()
      [item | _] = site.items

      assert item.position == 1

      {:ok, site} = Sites.promote_item(site, "#{item.id}")

      [item_after | _] = site.items

      assert item_after.position == 1
    end

    test "update_site/2 with valid data updates the site" do
      site = site_fixture()
      assert {:ok, %Site{} = site} = Sites.update_site(site, @update_attrs)
      assert site.name == "some updated name"
    end

    test "update_site/2 with invalid data returns error changeset" do
      user = user_fixture()
      site = site_fixture(user)
      assert {:error, %Ecto.Changeset{}} = Sites.update_site(site, @invalid_attrs)
      assert site == Sites.get_site!(user, site.id)
    end

    test "delete_site/1 deletes the site" do
      user = user_fixture()
      site = site_fixture(user)
      assert {:ok, %Site{}} = Sites.delete_site(site)
      assert_raise Ecto.NoResultsError, fn -> Sites.get_site!(user, site.id) end
    end

    test "change_site/1 returns a site changeset" do
      site = site_fixture()
      assert %Ecto.Changeset{} = Sites.change_site(site)
    end
  end

  describe "items" do
    alias Affable.Sites.Item

    @valid_attrs %{
      description: "some description",
      image_url: "some image_url",
      name: "some name",
      position: 42,
      price: Decimal.new("120.5"),
      url: "some url"
    }
    @update_attrs %{
      description: "some updated description",
      image_url: "some updated image_url",
      name: "some updated name",
      position: 43,
      price: Decimal.new("456.7"),
      url: "some updated url"
    }
    @invalid_attrs %{
      description: nil,
      image_url: nil,
      name: nil,
      position: nil,
      price: nil,
      url: nil
    }

    def item_fixture(attrs \\ %{}) do
      {:ok, item} =
        Sites.create_item(
          site_fixture(),
          attrs
          |> Enum.into(@valid_attrs)
        )

      item
    end

    test "list_items/0 returns all items" do
      item = item_fixture()
      assert Sites.list_items() |> Enum.member?(item)
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Sites.get_item!(item.id) == item
    end

    test "create_item/2 with valid data creates a item" do
      assert {:ok, %Item{} = item} = Sites.create_item(site_fixture(), @valid_attrs)
      assert item.description == "some description"
      assert item.image_url == "some image_url"
      assert item.name == "some name"
      assert item.position == 42
      assert item.price == Decimal.new("120.5")
      assert item.url == "some url"
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sites.create_item(site_fixture(), @invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()
      assert {:ok, %Item{} = item} = Sites.update_item(item, @update_attrs)
      assert item.description == "some updated description"
      assert item.image_url == "some updated image_url"
      assert item.name == "some updated name"
      assert item.position == 43
      assert item.price == Decimal.new("456.7")
      assert item.url == "some updated url"
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Sites.update_item(item, @invalid_attrs)
      assert item == Sites.get_item!(item.id)
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Sites.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Sites.get_item!(item.id) end
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Sites.change_item(item)
    end
  end
end
