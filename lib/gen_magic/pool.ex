defmodule GenMagic.Pool do
  @behaviour NimblePool

  def start_link(options, pool_size \\ nil) do
    pool_size = pool_size || System.schedulers_online()
    NimblePool.start_link(worker: {__MODULE__, options}, pool_size: pool_size)
  end

  def perform(pool, path, opts \\ []) do
    pool_timeout = Keyword.get(opts, :pool_timeout, 5000)
    timeout = Keyword.get(opts, :timeout, 5000)

    NimblePool.checkout!(pool, :checkout, fn _from, server ->
      {GenMagic.perform(server, path, timeout), server}
    end, pool_timeout)
  end

  @impl NimblePool
  def init_pool(options) do
    {name, options} = case Keyword.pop(options, :name) do
      {name, options} when is_atom(name) -> {name, options}
      {nil, options} -> {__MODULE__, options}
      {_, options} -> {nil, options}
    end
    if name, do: Process.register(self(), atom)
    {:ok, options}
  end

  @impl NimblePool
  def init_worker(options) do
    {:ok, server} = GenMagic.Server.start_link(options)
    {:ok, server, nil}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _, server, state) do
    {:ok, server, server, pool_state}
  end

  @impl NimblePool
  def handle_checkin(server, _from, _old_server, state) do
    {:ok, server, state}
  end

  @impl NimblePool
  def terminate_worker(_reason, _worker, state) do
    {:ok, state}
  end

  @impl NimblePool
  def terminate(_reason, _conn, state) do
    {:ok, state}
  end

end
