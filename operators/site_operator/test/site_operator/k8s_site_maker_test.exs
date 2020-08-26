defmodule SiteOperator.K8sSiteMakerTest do
  use ExUnit.Case, async: true

  alias SiteOperator.{K8sSiteMaker, SiteMaker, MockK8s}

  alias SiteOperator.K8s.{
    AffiliateSite,
    Certificate,
    Namespace,
    RoleBinding,
    Service,
    Operation,
    Operations
  }

  import SiteOperator.K8sConversions, only: [to_k8s: 1]
  import Hammox

  @namespace "generatedname"
  @domains ["testdomain.example.com"]
  @irrelevant ""

  setup :verify_on_exit!

  setup do
    Hammox.protect(
      K8sSiteMaker,
      SiteMaker,
      create: 1,
      delete: 1,
      reconcile: 1
    )
  end

  describe "creation" do
    test "executes operation batches in order",
         %{create_1: create} do
      ns = Operations.create(%Namespace{name: @namespace})
      cert = Operations.create(%Certificate{name: @namespace, domains: @domains})

      service = Operations.create(%Service{name: "please", namespace: @namespace})

      batch_1 = [ns, cert]
      batch_2 = [service]

      expect(MockK8s, :execute, fn [^ns, ^cert] ->
        expect(MockK8s, :execute, fn [^service] ->
          {:ok, "don't match on this"}
        end)

        {:ok, ""}
      end)

      {:ok, _} = create.([batch_1, batch_2])
    end

    test "returns error when we get a k8s error", %{create_1: create} do
      MockK8s
      |> stub(:execute, fn _ ->
        {:error, "Bad news"}
      end)

      result = create.([[Operations.create(%Namespace{name: @namespace})]])

      assert elem(result, 0) == :error
      assert elem(result, 1) == "Bad news"
    end
  end

  describe "deletion" do
    test "deletes namespace and certificate in parallel", %{delete_1: delete} do
      MockK8s
      |> expect(:execute, fn operations ->
        assert operations == Operations.deletions(@namespace)
        {:ok, "pass message through"}
      end)

      {:ok, "pass message through"} = delete.(@namespace)
    end
  end

  describe "reconciliation" do
    test "does nothing when namespace, rolebinding and cert are available", %{
      reconcile_1: reconcile
    } do
      stub(MockK8s, :execute, fn [
                                   %Operation{action: :get},
                                   %Operation{action: :get},
                                   %Operation{action: :get}
                                 ] ->
        {:ok, "Some message"}
      end)

      assert reconcile.(%AffiliateSite{
               name: @namespace,
               image: "irrelevant",
               domains: @domains,
               secret_key_base: "a-secret",
               distribution_cookie: ""
             }) == {:ok, :nothing_to_do}
    end

    test "creates missing rolebinding", %{reconcile_1: reconcile} do
      binding = %RoleBinding{
        name: "endpoint-listing-for-#{@namespace}",
        namespace: "affable",
        role_kind: "ClusterRole",
        role_name: "endpoint-lister",
        subjects: [%{kind: "ServiceAccount", name: "default", namespace: @namespace}]
      }

      binding_k8s = binding |> to_k8s

      stub(MockK8s, :execute, fn [_, _, %Operation{action: :get, resource: ^binding_k8s}] ->
        expect(MockK8s, :execute, fn [%Operation{action: :create, resource: ^binding_k8s}] ->
          {:ok, ""}
        end)

        {:error, some_resources_missing: [binding]}
      end)

      {:ok, recreated: [^binding]} =
        reconcile.(%AffiliateSite{
          name: @namespace,
          image: "irrelevant",
          domains: @domains,
          secret_key_base: "a-secret",
          distribution_cookie: @irrelevant
        })
    end

    test "creates missing certificate", %{reconcile_1: reconcile} do
      cert = %Certificate{name: @namespace, domains: @domains}
      cert_k8s = cert |> to_k8s

      stub(MockK8s, :execute, fn [_, %Operation{action: :get, resource: ^cert_k8s}, _] ->
        expect(MockK8s, :execute, fn [%Operation{action: :create, resource: ^cert_k8s}] ->
          {:ok, ""}
        end)

        {:error, some_resources_missing: [cert]}
      end)

      {:ok, recreated: [^cert]} =
        reconcile.(%AffiliateSite{
          name: @namespace,
          image: "irrelevant",
          domains: @domains,
          secret_key_base: "a-secret",
          distribution_cookie: @irrelevant
        })
    end

    test "creates missing namespace and its resources", %{reconcile_1: reconcile} do
      ns = %Namespace{name: @namespace}
      ns_k8s = ns |> to_k8s

      site = %AffiliateSite{
        name: @namespace,
        image: "some-image",
        domains: @domains,
        secret_key_base: "a-new-secret",
        distribution_cookie: "new-cookie"
      }

      stub(MockK8s, :execute, fn [%Operation{action: :get, resource: ^ns_k8s}, _, _] ->
        expect(MockK8s, :execute, fn [%Operation{action: :create, resource: ^ns_k8s}] ->
          expect(MockK8s, :execute, fn operations ->
            assert operations == Operations.inner_ns_creations(site)
            {:ok, "don't match on this"}
          end)

          {:ok, ""}
        end)

        {:error, some_resources_missing: [ns]}
      end)

      {:ok, recreated: [^ns]} = reconcile.(site)
    end
  end
end
