if Code.ensure_loaded?(Plug) do
  defmodule Majic.PlugError do
    defexception [:message]
  end

  defmodule Majic.Plug do
    @moduledoc """
    A `Plug` to automatically set the `content_type` of every `Plug.Upload`.

    One of the required option of `pool`, `server` or `once` must be set.

    Additional options:
    * `fix_extension`, default true: enable use of `Majic.Extension`,
    * options for `Majic.Extension`.

    To use a majic pool:

    ```
    plug Majic.Plug, pool: MyApp.MajicPool
    ```

    To use a single majic server:

    ```
    plug Majic.Plug, server: MyApp.MajicServer
    ```

    To start a majic process at each file (not recommended):

    ```
    plug Majic.Plug, once: true
    ```
    """
    @behaviour Plug

    @impl Plug
    def init(opts) do
      cond do
        Keyword.has_key?(opts, :pool) -> true
        Keyword.has_key?(opts, :server) -> true
        Keyword.has_key?(opts, :once) -> true
        true -> raise(Majic.PlugError, "No server/pool/once option defined")
      end

      opts
      |> Keyword.put_new(:fix_extension, true)
      |> Keyword.put_new(:append, false)
      |> Keyword.put_new(:subtype_as_extension, false)
    end

    @impl Plug
    def call(conn, opts) do
      collected = collect_uploads([], conn.body_params, [])

      Enum.reduce(collected, conn, fn {param_path, upload}, conn ->
        {array_index, param_path} =
          case param_path do
            [index, :array | path] ->
              {index, path}

            path ->
              {nil, path}
          end

        param_path = Enum.reverse(param_path)

        upload =
          case Majic.perform(upload.path, opts) do
            {:ok, magic} -> fix_upload(upload, magic, opts)
            {:error, error} -> raise(Majic.PlugError, "Failed to majic: #{inspect(error)}")
          end

        conn
        |> put_in_if_exists(:params, param_path, upload, array_index)
        |> put_in_if_exists(:body_params, param_path, upload, array_index)
      end)
    end

    defp collect_uploads(path, params, acc) do
      Enum.reduce(params, acc, fn value, acc -> collect_upload(path, value, acc) end)
    end

    # An upload!
    defp collect_upload(path, {k, %{__struct__: Plug.Upload} = upload}, acc) do
      [{[k | path], upload} | acc]
    end

    # Ignore structs.
    defp collect_upload(_path, {_, %{__struct__: _}}, acc) do
      acc
    end

    # Nested map.
    defp collect_upload(path, {k, v}, acc) when is_map(v) do
      collect_uploads([k | path], v, acc)
    end

    defp collect_upload(path, {k, v}, acc) when is_list(v) do
      Enum.reduce(Enum.with_index(v), acc, fn {item, index}, acc ->
        collect_upload([:array, k | path], {index, item}, acc)
      end)
    end

    defp collect_upload(_path, _, acc) do
      acc
    end

    defp fix_upload(upload, magic, opts) do
      filename =
        if Keyword.get(opts, :fix_extension) do
          ext_opts = [
            append: Keyword.get(opts, :append, false),
            subtype_as_extension: Keyword.get(opts, :subtype_as_extension, false)
          ]

          Majic.Extension.fix(upload.filename, magic, ext_opts)
        end

      %{upload | content_type: magic.mime_type, filename: filename || upload.filename}
    end

    # put value at path in conn.
    defp put_in_if_exists(conn, key, path, value, nil) do
      if get_in(Map.get(conn, key), path) do
        Map.put(conn, key, put_in(Map.get(conn, key), path, value))
      else
        conn
      end
    end

    # change value at index in list at path in conn.
    defp put_in_if_exists(conn, key, path, value, index) do
      if array = get_in(Map.get(conn, key), path) do
        array = List.replace_at(array, index, value)
        Map.put(conn, key, put_in(Map.get(conn, key), path, array))
      else
        conn
      end
    end
  end
end
