name =
  case System.cmd("git", ~w(describe --all --long --dirty --broken --always)) do
    {name, 0} -> String.trim(name)
    _ -> "cannot-git-describe"
  end

repo = System.get_env("TEST_REPO") || "https://git.sr.ht/~href/gen_magic"

IO.puts("Using repository: #{repo}")

token = System.get_env("SR_HT_TOKEN")

unless token do
  IO.puts("""
  sr.ht token not defined (SR_HT_TOKEN)\n\n
  Get one at https://meta.sr.ht/oauth/personal-token\n
  Define one by setting the SR_HT_TOKEN environment variable
  """)
else
  Application.ensure_all_started(:ssl)
  Application.ensure_all_started(:inets)

  File.ls!(".builds")
  |> Enum.filter(fn file -> Path.extname(file) == ".yaml" end)
  |> Enum.each(fn file ->
    file = Path.join(".builds", file)
    build = Path.basename(file, ".yaml")

    build =
      %{
        "manifest" => File.read!(file),
        "note" => "gen_magic/#{name} #{build}",
        "tags" => ["gen_magic"]
      }
      |> Jason.encode!()

    case :httpc.request(
           :post,
           {'https://builds.sr.ht/api/jobs', [{'authorization', 'token ' ++ to_charlist(token)}],
            'application/json', build},
           [],
           []
         ) do
      {:ok, {{_http_v, 200, 'OK'}, _headers, body}} ->
        resp = Jason.decode!(body)
        IO.puts("#{resp["status"]} job #{resp["note"]}, id: #{resp["id"]}")

      error ->
        IO.puts("Failed to enqueue job #{inspect(error)}")
    end
  end)
end
