defmodule Majic.PlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule TestRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    plug(Plug.Parsers,
      parsers: [:urlencoded, :multipart],
      pass: ["*/*"]
    )

    # plug Majic.Plug, once: true

    post "/" do
      send_resp(conn, 200, "Ok")
    end
  end

  setup_all do
    Application.ensure_all_started(:plug)
    :ok
  end

  @router_opts TestRouter.init([])

  test "convert uploads" do
    multipart = """
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"form[makefile]\"; filename*=\"utf-8''mymakefile.txt\"\r
    Content-Type: text/plain\r
    \r
    #{File.read!("Makefile")}\r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"form[make][file]\"; filename*=\"utf-8''mymakefile.txt\"\r
    Content-Type: text/plain\r
    \r
    #{File.read!("Makefile")}\r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"cat\"; filename*=\"utf-8''cute-cat.jpg\"\r
    Content-Type: image/jpg\r
    \r
    #{File.read!("test/fixtures/cat.webp")}\r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"cats[]\"; filename*=\"utf-8''first-cute-cat.jpg\"\r
    Content-Type: image/jpg\r
    \r
    #{File.read!("test/fixtures/cat.webp")}\r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"cats[]\"\r
    \r
    hello i am annoying
    \r
    ------w58EW1cEpjzydSCq\r
    Content-Disposition: form-data; name=\"cats[]\"; filename*=\"utf-8''second-cute-cat.jpg\"\r
    Content-Type: image/jpg\r
    \r
    #{File.read!("test/fixtures/cat.webp")}\r
    ------w58EW1cEpjzydSCq--\r
    """

    orig_conn =
      conn(:post, "/", multipart)
      |> put_req_header("content-type", "multipart/mixed; boundary=----w58EW1cEpjzydSCq")
      |> TestRouter.call(@router_opts)

    plug = Majic.Plug.init(once: true)
    plug_no_ext = Majic.Plug.init(once: true, fix_extension: false)
    plug_append_ext = Majic.Plug.init(once: true, fix_extension: true, append_extension: true)

    conn = Majic.Plug.call(orig_conn, plug)
    conn_no_ext = Majic.Plug.call(orig_conn, plug_no_ext)
    conn_append_ext = Majic.Plug.call(orig_conn, plug_append_ext)

    assert conn.state == :sent
    assert conn.status == 200

    assert get_in(conn.body_params, ["form", "makefile"]) ==
             get_in(conn.params, ["form", "makefile"])

    assert get_in(conn.params, ["form", "makefile"]).content_type == "text/x-makefile"
    assert get_in(conn.params, ["form", "makefile"]).filename == "mymakefile"
    assert get_in(conn_no_ext.params, ["form", "makefile"]).filename == "mymakefile.txt"
    assert get_in(conn_append_ext.params, ["form", "makefile"]).filename == "mymakefile.txt"

    assert get_in(conn.body_params, ["form", "make", "file"]) ==
             get_in(conn.params, ["form", "make", "file"])

    assert get_in(conn.params, ["form", "make", "file"]).content_type == "text/x-makefile"

    assert get_in(conn.body_params, ["cat"]) == get_in(conn.params, ["cat"])
    assert get_in(conn.params, ["cat"]).content_type == "image/webp"
    assert get_in(conn.params, ["cat"]).filename == "cute-cat.webp"
    assert get_in(conn_no_ext.params, ["cat"]).filename == "cute-cat.jpg"
    assert get_in(conn_append_ext.params, ["cat"]).filename == "cute-cat.jpg.webp"

    assert Enum.all?(conn.params["cats"], fn
      %Plug.Upload{} = upload -> upload.content_type == "image/webp"
      _ -> true
    end)
  end
end
