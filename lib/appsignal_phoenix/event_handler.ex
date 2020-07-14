defmodule Appsignal.Phoenix.EventHandler do
  @tracer Application.get_env(:appsignal, :appsignal_tracer, Appsignal.Tracer)
  @span Application.get_env(:appsignal, :appsignal_span, Appsignal.Span)
  @moduledoc false

  def attach do
    handlers = %{
      [:phoenix, :router_dispatch, :start] => &phoenix_router_dispatch_start/4,
      [:phoenix, :endpoint, :start] => &phoenix_endpoint_start/4,
      [:phoenix, :endpoint, :stop] => &phoenix_endpoint_stop/4
    }

    for {event, fun} <- handlers do
      :telemetry.attach({__MODULE__, event}, event, fun, :ok)
    end
  end

  defp phoenix_router_dispatch_start(
         _,
         _measurements,
         %{plug: controller, plug_opts: action},
         _config
       )
       when is_atom(action) do
    span = @tracer.root_span()
    name = "#{module_name(controller)}##{action}"

    @span.set_name(span, name)
  end

  defp phoenix_router_dispatch_start(_event, _measurements, _metadata, _config) do
    :ok
  end

  def phoenix_endpoint_start(
        _event,
        _measurements,
        %{conn: %Plug.Conn{private: %{phoenix_endpoint: endpoint}}},
        _config
      ) do
    parent = @tracer.current_span()

    "http_request"
    |> @tracer.create_span(parent)
    |> @span.set_name("#{module_name(endpoint)}.call/2")
    |> @span.set_attribute("appsignal:category", "endpoint.call")
  end

  defp phoenix_endpoint_stop(_event, _measurements, _metadata, _config) do
    @tracer.close_span(@tracer.current_span())
  end

  defp module_name("Elixir." <> module), do: module
  defp module_name(module) when is_binary(module), do: module
  defp module_name(module), do: module |> to_string() |> module_name()
end
