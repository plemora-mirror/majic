defmodule GenMagic do
  @moduledoc """
  Top-level namespace for GenMagic, the libmagic client for Elixir.

  See `GenMagic.Server` or the README for usage.
  """

  @doc """
  Perform on `path`.

  An option of `server: ServerName`, `pool: PoolName` or `once: true` must be passed.
  """
  @type option :: name
    when name: {:pool, atom()} | {:server, GenMagic.Server.t()} | {:once, true}

  @spec perform(GenMagic.Server.target(), [option()]) :: GenMagic.Server.result()
  def perform(path, opts, timeout \\ 5000) do
    mod = cond do
      Keyword.has_key?(opts, :pool) -> {GenMagic.Pool, Keyword.get(opts, :pool)}
      Keyword.has_key?(opts, :server) -> {GenMagic.Server, Keyword.get(opts, :server)}
      Keyword.has_key?(opts, :once) -> {GenMagic.Helpers, nil}
      true -> nil
    end

    if mod do
      do_perform(mod, path, timeout)
    else
      {:error, :no_method}
    end
  end

  defp do_perform({GenMagic.Helpers, _}, path, timeout) do
    GenMagic.Helpers.perform_once(path, timeout)
  end

  defp do_perform({mod, name}, path, timeout) do
    mod.perform(name, path, tiemout)
  end

end
