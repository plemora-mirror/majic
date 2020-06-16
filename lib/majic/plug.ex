if Code.ensure_loaded?(Plug) do
  defmodule Majic.PlugError do
    defexception [:message]
  end

  defmodule Majic.Plug do
    @moduledoc """
    A `Plug` to automatically set the `content_type` of every `Plug.Upload`.

    One of the required option of `pool`, `server` or `once` must be set.

    Additional options:
    * `fix_extension`, default true: rewrite the user provided `filename` with a valid extension for the detected content type
    * `append_extension`, default false: append the valid extension to the previous filename, without removing the user provided extension

    To use a gen_magic pool:

    ```
    plug Majic.Plug, pool: MyApp.MajicPool
    ```

    To use a single gen_magic server:

    ```
    plug Majic.Plug, server: MyApp.MajicServer
    ```

    To start a gen_magic process at each file (not recommended):

    ```
    plug Majic.Plug, once: true
    ```
    """
    @behaviour Plug

    @impl Plug
    def init(opts) do
      mod =
        cond do
          Keyword.has_key?(opts, :pool) -> {Majic.Pool, Keyword.get(opts, :pool)}
          Keyword.has_key?(opts, :server) -> {Majic.Server, Keyword.get(opts, :server)}
          Keyword.has_key?(opts, :once) -> {Majic.Once, nil}
          true -> raise(Majic.PlugError, "No server/pool/once option defined")
        end

      opts
      |> Keyword.put(:__module__, mod)
      |> Keyword.put_new(:fix_extension, true)
      |> Keyword.put_new(:append_extension, false)
    end

    @impl Plug
    def call(%{params: params} = conn, opts) do
      %{conn | params: collect_uploads(params, opts)}
    end

    defp collect_uploads(params, opts) do
      Enum.reduce(params, Map.new(), fn value, acc -> collect_upload(value, acc, opts) end)
    end

    defp collect_upload({k, %{__struct__: Plug.Upload, path: path} = upload}, acc, opts) do
      case perform(Keyword.get(opts, :__module__), path) do
        {:ok, magic} ->
          Map.put(acc, k, fix_upload(upload, magic, opts))

        {:error, error} ->
          raise(Majic.PlugError, "Failed to gen_magic: #{inspect(error)}")
      end
    end

    defp collect_upload({k, v}, acc, opts) when is_map(v) do
      Map.put(acc, k, collect_uploads(v, opts))
    end

    defp collect_upload({k, v}, acc, _opts) do
      Map.put(acc, k, v)
    end

    defp perform({mod = Majic.Once, _}, path) do
      mod.perform(path)
    end

    defp perform({mod, name}, path) do
      mod.perform(name, path)
    end

    defp fix_upload(upload, magic, opts) do
      %{upload | content_type: magic.mime_type}
      |> fix_extension(Keyword.get(opts, :fix_extension), opts)
    end

    defp fix_extension(upload, true, opts) do
      old_ext = String.downcase(Path.extname(upload.filename))
      extensions = MIME.extensions(upload.content_type)
      rewrite_extension(upload, old_ext, extensions, opts)
    end

    defp fix_extension(upload, _, _) do
      upload
    end

    defp rewrite_extension(upload, _old, [], _opts) do
      upload
    end

    defp rewrite_extension(upload, old, [ext | _] = exts, opts) do
      if old in exts do
        upload
      else
        basename = Path.basename(upload.filename, old)

        %{
          upload
          | filename:
              rewrite_or_append_extension(
                basename,
                old,
                ext,
                Keyword.get(opts, :append_extension)
              )
        }
      end
    end

    defp rewrite_or_append_extension(basename, "." <> old, ext, true) do
      Enum.join([basename, old, ext], ".")
    end

    defp rewrite_or_append_extension(basename, _, ext, _) do
      basename <> "." <> ext
    end
  end
end
