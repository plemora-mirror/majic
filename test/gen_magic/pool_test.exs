defmodule GenMagic.PoollTest do
  use GenMagic.MagicCase

  test "pool" do
    {:ok, _} = GenMagic.Pool.start_link([name: TestPool])
    assert {:ok, _} = GenMagic.Pool.perform(TestPool, absolute_path("Makefile"))
  end

end
