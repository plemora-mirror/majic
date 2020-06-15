defmodule Soak do
  @moduledoc """
  Run with a list of files to inspect:

      find /usr/share/ -name *png | xargs mix run test/soak.exs
  """

  def perform_infinite([]), do: false

  def perform_infinite(paths) do
    {:ok, pid} = Majic.Server.start_link(database_patterns: ["/usr/local/share/misc/*.mgc"])

    perform_infinite(paths, [], pid, 0)
  end

  defp perform_infinite([], done, pid, count) do
    perform_infinite(done, [], pid, count)
  end

  defp perform_infinite([path | paths], done, pid, count) do
    if rem(count, 1000) == 0, do: IO.puts(Integer.to_string(count))
    {:ok, %Majic.Result{}} = Majic.Server.perform(pid, path)
    perform_infinite(paths, [path | done], pid, count + 1)
  end
end

# Run with a list of files to inspect
#
#  find /usr/share/ -name *png | xargs mix run test/soak.exs

System.argv()
|> Enum.filter(&File.exists?/1)
|> Soak.perform_infinite()
