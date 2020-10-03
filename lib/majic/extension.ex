defmodule Majic.Extension do
  @moduledoc """
  Helper module to fix extensions. Uses [MIME](https://hexdocs.pm/mime/MIME.html).
  """

  @typedoc """
  If an extension is defined for a given MIME type, append it to the previous extension.

  If no extension could be found for the MIME type, and `subtype_as_extension: false`, the returned filename will have no extension.
  """
  @type option_append :: {:append, false | true}

  @typedoc "If no extension is defined for a given MIME type, use the subtype as its extension."
  @type option_subtype_as_extension :: {:subtype_as_extension, false | true}

  @spec fix(Path.t(), Majic.Result.t() | String.t(), [
          option_append() | option_subtype_as_extension()
        ]) :: Path.t()
  @doc """
  Fix `name`'s extension according to `result_or_mime_type`.

  ```elixir
  iex(1)> {:ok, result} = Majic.perform("cat.jpeg", once: true)
  {:ok, %Majic.Result{mime_type: "image/webp", ...}}
  iex(1)> Majic.Extension.fix("cat.jpeg", result)
  "cat.webp"
  ```

  The `append: true` option will append the correct extension to the user-provided one, if there's an extension for the
  type:

  ```
  iex(1)> Majic.Extension.fix("cat.jpeg", result, append: true)
  "cat.jpeg.webp"
  iex(2)> Majic.Extension.fix("Makefile.txt", "text/x-makefile", append: true)
  "Makefile"
  ```

  The `subtype_as_extension: true` option will use the subtype part of the MIME type as an extension for the ones that
  don't have any:

  ```elixir
  iex(1)> Majic.Extension.fix("Makefile.txt", "text/x-makefile", subtype_as_extension: true)
  "Makefile.x-makefile"
  iex(1)> Majic.Extension.fix("Makefile.txt", "text/x-makefile", subtype_as_extension: true, append: true)
  "Makefile.txt.x-makefile"
  ```
  """
  def fix(name, result_or_mime_type, options \\ [])

  def fix(name, %Majic.Result{mime_type: mime_type}, options) do
    do_fix(name, mime_type, options)
  end

  def fix(name, mime_type, options) do
    do_fix(name, mime_type, options)
  end

  defp do_fix(name, mime_type, options) do
    append? = Keyword.get(options, :append, false)
    subtype? = Keyword.get(options, :subtype_as_extension, false)
    exts = MIME.extensions(mime_type) ++ subtype_extension(subtype?, mime_type)
    old_ext = String.downcase(Path.extname(name))

    unless old_ext == "" do
      basename = Path.basename(name, old_ext)
      "." <> old = old_ext

      if old in exts do
        Enum.join([basename, ".", old])
      else
        ext = List.first(exts)

        ext_list =
          cond do
            ext && append? -> [old, ext]
            !ext -> []
            ext -> [ext]
          end

        Enum.join([basename] ++ ext_list, ".")
      end
    else
      name
    end
  end

  defp subtype_extension(true, type) do
    [_type, sub] = String.split(type, "/", parts: 2)
    [sub]
  end

  defp subtype_extension(_, _), do: []
end
