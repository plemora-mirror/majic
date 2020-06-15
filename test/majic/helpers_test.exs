defmodule Majic.HelpersTest do
  use Majic.MagicCase
  doctest Majic.Helpers

  test "perform_once" do
    path = absolute_path("Makefile")
    assert {:ok, %{mime_type: "text/x-makefile"}} = Majic.Helpers.perform_once(path)
  end
end
