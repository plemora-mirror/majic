defmodule Majic.ServerTest do
  use Majic.MagicCase
  doctest Majic.Server

  describe "recycle_threshold" do
    test "resets" do
      {:ok, pid} = Majic.Server.start_link(recycle_threshold: 3)
      path = absolute_path("Makefile")
      assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
      assert {:ok, _} = Majic.Server.perform(pid, path)
      assert {:ok, %{cycles: 1}} = Majic.Server.status(pid)
      assert {:ok, _} = Majic.Server.perform(pid, path)
      assert {:ok, %{cycles: 2}} = Majic.Server.status(pid)
      assert {:ok, _} = Majic.Server.perform(pid, path)
      Process.sleep(100)
      assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
    end

    test "resets before reply" do
      {:ok, pid} = Majic.Server.start_link(recycle_threshold: 1)
      path = absolute_path("Makefile")
      assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
      assert {:ok, _} = Majic.Server.perform(pid, path)
      Process.sleep(100)
      assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
      assert {:ok, _} = Majic.Server.perform(pid, path)
      Process.sleep(100)
      assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
      assert {:ok, _} = Majic.Server.perform(pid, path)
      Process.sleep(100)
      assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
    end
  end

  test "recycle" do
    {:ok, pid} = Majic.Server.start_link([])
    path = absolute_path("Makefile")
    assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
    assert {:ok, _} = Majic.Server.perform(pid, path)
    assert {:ok, %{cycles: 1}} = Majic.Server.status(pid)
    assert :ok = Majic.Server.recycle(pid)
    assert {:ok, %{cycles: 0}} = Majic.Server.status(pid)
  end
end
