defmodule SiteOperator.RealK8sTest do
  use ExUnit.Case, async: false
  @moduletag :external
  @cluster :test

  alias SiteOperator.K8s.{
    Certificate,
    Deployment,
    Gateway,
    Namespace,
    Operations,
    Service,
    VirtualService
  }

  setup_all do
    conn = K8s.Conn.from_file("/tmp/microk8s-config", context: "microk8s")
    {:ok, _} = K8s.Cluster.Registry.add(@cluster, conn)

    certificate = %Certificate{
      name: "test-name",
      domains: ["testcertificate.example.com"]
    }

    deployment = %Deployment{
      name: "test-name",
      image: "nginx",
      namespace: "test-name",
      env_vars: %{}
    }

    gateway = %Gateway{
      name: "test-name",
      namespace: "test-name",
      domains: ["testgateway.example.com"]
    }

    namespace = %Namespace{
      name: "test-name"
    }

    service = %Service{
      name: "test-name",
      namespace: "test-name"
    }

    virtual_service = %VirtualService{
      name: "test-name",
      namespace: "test-name",
      gateways: ["test-name"],
      domains: ["testvirtualservice.example.com"]
    }

    on_exit(fn ->
      SiteOperator.RealK8s.execute([
        Operations.delete(certificate),
        Operations.delete(namespace)
      ])
    end)

    %{
      certificate: certificate,
      deployment: deployment,
      gateway: gateway,
      namespace: namespace,
      service: service,
      virtual_service: virtual_service
    }
  end

  setup_all do
    Hammox.protect(
      SiteOperator.RealK8s,
      SiteOperator.K8s
    )
  end

  test "all the things", %{
    execute_1: execute,
    certificate: certificate,
    deployment: deployment,
    gateway: gateway,
    namespace: namespace,
    service: service,
    virtual_service: virtual_service
  } do
    {:ok, _} =
      execute.([
        Operations.create(namespace)
      ])

    {:error, _errors} =
      execute.([
        Operations.create(%Namespace{name: "<>!@#!@bad"})
      ])

    {:ok, _} =
      execute.([
        Operations.create(certificate),
        Operations.create(deployment),
        Operations.create(gateway),
        Operations.create(service),
        Operations.create(virtual_service)
      ])

    assert execute.([
             Operations.get(certificate),
             Operations.get(deployment),
             Operations.get(gateway),
             Operations.get(namespace),
             Operations.get(service),
             Operations.get(virtual_service)
           ]) ==
             {:ok,
              [
                certificate,
                deployment,
                gateway,
                namespace,
                service,
                virtual_service
              ]}

    missing_namespace = %Namespace{name: "bogus"}

    assert execute.([
             Operations.get(certificate),
             Operations.get(missing_namespace)
           ]) ==
             {:error, some_resources_missing: [missing_namespace]}

    # no change
    assert execute.([
             Operations.update(deployment)
           ]) == {:ok, [deployment]}

    # change the image
    assert execute.([
             Operations.update(%{deployment | image: "alpine"})
           ]) == {:ok, [%{deployment | image: "alpine"}]}

    # change affects gets
    assert execute.([
             Operations.get(deployment)
           ]) == {:ok, [%{deployment | image: "alpine"}]}
  end
end
