ExUnit.start()

restore_ulimit =
  case System.cmd("env", ["sh", "-c", "ulimit -c"]) do
    {"unlimited\n", 0} ->
      nil

    {old, 0} ->
      case System.cmd("env", ["sh", "-c", "ulimit -c unlimited"]) do
        {_, 0} ->
          IO.puts("Enabled coredumps with ulimit.")
          old

        error ->
          IO.puts("Failed to enable coredumps: #{inspect(error)}")
      end

    error ->
      IO.puts("Couldn't use ulimit for coredumps: #{inspect(error)}")
      nil
  end

if System.get_env("TEAMCITY_VERSION") do
  ExUnit.configure(formatters: [TeamCityFormatter])
end

ExUnit.configure(exclude: [external: true], capture_log: true)

if restore_ulimit do
  System.cmd("env", ["sh", "-c", "ulimit -c #{String.trim(restore_ulimit)}"])
end
