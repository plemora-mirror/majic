defmodule Majic.PoollTest do
  use Majic.MagicCase

  test "pool" do
    {:ok, _} = Majic.Pool.start_link(name: TestPool, pool_size: 2)
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.Pool.perform(TestPool, absolute_path("Makefile"))
    assert {:ok, _} = Majic.perform(absolute_path("Makefile"), pool: TestPool)
  end
end
