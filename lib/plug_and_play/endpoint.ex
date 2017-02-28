defmodule PlugAndPlay.Endpoint do
  defmacro __using__(opts) do
    quote do
      @otp_app unquote(opts)[:otp_app] || raise "endpoint expects :otp_app to be given"
      var!(config) = Phoenix.Endpoint.Supervisor.config(@otp_app, __MODULE__)
      var!(code_reloading?) = var!(config)[:code_reloader]

      @doc """
      Starts the endpoint supervision tree.
      """
      def start_link do
        PlugAndPlay.Supervisor.start_link(@otp_app, __MODULE__)
      end

      @doc """
      Returns the endpoint configuration for `key`
      Returns `default` if the key does not exist.
      """
      def config(key, default \\ nil) do
        case :ets.lookup(__MODULE__, key) do
          [{^key, val}] -> val
          [] -> default
        end
      end

      @doc """
      Reloads the configuration given the application environment changes.
      """
      def config_change(changed, removed) do
        Phoenix.Endpoint.Supervisor.config_change(__MODULE__, changed, removed)
      end

      @doc """
      Generates the endpoint base URL without any path information.
      It uses the configuration under `:url` to generate such.
      """
      def url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_url__,
          &Phoenix.Endpoint.Supervisor.url/1)
      end

      @doc """
      Generates the static URL without any path information.
      It uses the configuration under `:static_url` to generate
      such. It falls back to `:url` if `:static_url` is not set.
      """
      def static_url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_static_url__,
          &Phoenix.Endpoint.Supervisor.static_url/1)
      end

      @doc """
      Generates the endpoint base URL but as a `URI` struct.
      It uses the configuration under `:url` to generate such.
      Useful for manipulating the URL data and passing it to
      URL helpers.
      """
      def struct_url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_struct_url__,
          &Phoenix.Endpoint.Supervisor.struct_url/1)
      end

      @doc """
      Returns the host for the given endpoint.
      """
      def host do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_host__,
          &Phoenix.Endpoint.Supervisor.host/1)
      end

      @doc """
      Generates the path information when routing to this endpoint.
      """
      def path(path) do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_path__,
          &Phoenix.Endpoint.Supervisor.path/1) <> path
      end

      @doc """
      Generates the script name.
      """
      def script_name do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_script_name__,
          &Phoenix.Endpoint.Supervisor.script_name/1)
      end

      @doc """
      Generates a route to a static file in `priv/static`.
      """
      def static_path(path) do
        Phoenix.Config.cache(__MODULE__, :__phoenix_static__,
                             &Phoenix.Endpoint.Supervisor.static_path/1) <>
        Phoenix.Config.cache(__MODULE__, {:__phoenix_static__, path},
                             &Phoenix.Endpoint.Supervisor.static_path(&1, path))
      end
    end
  end

  @doc false
  def __force_ssl__(module, config) do
    if force_ssl = config[:force_ssl] do
      host = force_ssl[:host] || config[:url][:host] || "localhost"

      if host == "localhost" do
        IO.puts :stderr, """
        warning: you have enabled :force_ssl but your host is currently set to localhost.
        Please configure your endpoint url host properly:
            config #{inspect module}, url: [host: "YOURHOST.com"]
        """
      end

      Keyword.put_new(force_ssl, :host, {module, :host, []})
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    sockets = Module.get_attribute(env.module, :phoenix_sockets)
    otp_app = Module.get_attribute(env.module, :otp_app)
    instrumentation = Phoenix.Endpoint.Instrument.definstrument(otp_app, env.module)

    quote do
      defoverridable [call: 2]

      # Inline render errors so we set the endpoint before calling it.
      def call(conn, opts) do
        conn = put_in conn.secret_key_base, config(:secret_key_base)
        conn = put_in conn.script_name, script_name()
        conn = Plug.Conn.put_private(conn, :phoenix_endpoint, __MODULE__)

        try do
          super(conn, opts)
        catch
          kind, reason ->
            Phoenix.Endpoint.RenderErrors.__catch__(conn, kind, reason, @phoenix_render_errors)
        end
      end

      @doc """
      Returns all sockets configured in this endpoint.
      """
      def __sockets__, do: unquote(sockets)

      unquote(instrumentation)
    end
  end


    quote do
      use Supervisor

      def start(_type, _args) do
        PlugAndPlay.Supervisor.start_link(unquote(root_module))
      end
    end
  end
end
