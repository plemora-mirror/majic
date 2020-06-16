defmodule Majic do
  alias Majic.{Once, Pool, Result, Server}

  @moduledoc """
  Robust libmagic integration for Elixir.
  """

  @doc """
  Perform on `path`.

  An option of `server: ServerName`, `pool: PoolName` or `once: true` must be passed.
  """
  @type target :: Path.t() | {:bytes, binary()}
  @type result :: {:ok, Result.t()} | {:error, term() | String.t()}
  @type name :: {:pool, atom()} | {:server, Server.t()} | {:once, true}
  @type option :: name | Server.start_option() | Pool.option()

  @spec perform(target(), [option()]) :: result()
  def perform(path, opts) do
    mod =
      cond do
        Keyword.has_key?(opts, :pool) -> {Pool, Keyword.get(opts, :pool)}
        Keyword.has_key?(opts, :server) -> {Server, Keyword.get(opts, :server)}
        Keyword.has_key?(opts, :once) -> {Once, nil}
        true -> nil
      end

    opts =
      opts
      |> Keyword.drop([:pool, :server, :once])

    if mod do
      do_perform(mod, path, opts)
    else
      {:error, :no_method}
    end
  end

  defp do_perform({Server = mod, name}, path, opts) do
    timeout = Keyword.get(opts, :timeout, Majic.Config.default_process_timeout())
    mod.perform(name, path, timeout)
  end

  defp do_perform({Once = mod, _}, path, opts) do
    mod.perform(path, opts)
  end

  defp do_perform({Pool = mod, name}, path, opts) do
    mod.perform(name, path, opts)
  end
end
