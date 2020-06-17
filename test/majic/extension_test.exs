defmodule Majic.ExtensionTest do
  use ExUnit.Case

  alias Majic.Extension

  test "it fixes extensions" do
    assert "Makefile" == Extension.fix("Makefile.txt", "text/x-makefile")
    assert "cat.webp" == Extension.fix("cat.jpeg", "image/webp")
  end

  test "it appends extensions" do
    assert "Makefile" == Extension.fix("Makefile.txt", "text/x-makefile", append: true)
    assert "cat.jpeg.webp" == Extension.fix("cat.jpeg", "image/webp", append: true)
  end

  test "it uses subtype as extension" do
    assert "Makefile.x-makefile" ==
             Extension.fix("Makefile.txt", "text/x-makefile", subtype_as_extension: true)

    assert "cat.webp" == Extension.fix("cat.jpeg", "image/webp", subtype_as_extension: true)
  end

  test "it appends and use subtype" do
    assert "Makefile.txt.x-makefile" ==
             Extension.fix("Makefile.txt", "text/x-makefile",
               subtype_as_extension: true,
               append: true
             )

    assert "cat.jpeg.webp" ==
             Extension.fix("cat.jpeg", "image/webp", subtype_as_extension: true, append: true)
  end
end
