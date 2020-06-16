defmodule Majic.OnceTest do
  use Majic.MagicCase
  doctest Majic.Once

  test "perform" do
    path = absolute_path("Makefile")
    assert {:ok, %{mime_type: "text/x-makefile"}} = Majic.Once.perform(path)
  end

  test "Majic.perform" do
    path = absolute_path("Makefile")
    assert {:ok, %{mime_type: "text/x-makefile"}} = Majic.perform(path, once: true)
  end
end
