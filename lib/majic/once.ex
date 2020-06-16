defmodule Majic.Once do
  @moduledoc """
  Contains convenience functions for one-off use.
  """

  alias Majic.Server

  @process_timeout Majic.Config.default_process_timeout()

  @spec perform(Majic.target(), [Server.start_option()], timeout()) :: Majic.result()

  @doc """
  Runs a one-shot process without supervision.

  Useful in tests, but not recommended for actual applications.

  ## Example

      iex(1)> {:ok, result} = Majic.Once.perform(".")
      iex(2)> result
      %Majic.Result{content: "directory", encoding: "binary", mime_type: "inode/directory"}
  """
  def perform(path, options \\ [], timeout \\ @process_timeout) do
    with {:ok, pid} <- Server.start_link(options),
         {:ok, result} <- Server.perform(pid, path, timeout),
         :ok <- Server.stop(pid) do
      {:ok, result}
    end
  end
end
