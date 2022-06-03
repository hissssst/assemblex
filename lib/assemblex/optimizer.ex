defmodule Assemblex.Optimizer do

  import Pathex
  import Pathex.Lenses

  def factsl() do
    path(:facts :: :map)
  end

  def pass_all(assembly) do
    assembly
    |> pass_pairs()
    |> pass_knowns(forget_all())
  end

  def pass_pairs(assembly) do
    case assembly do
      [{:push, [x]}, {:pop, [y]} | tail] ->
        IO.puts "pushpop!"
        pass_pairs([{:mov, [y, x]} | tail])

      [{:mov, [x, x]} | tail] ->
        IO.puts "movself!"
        pass_pairs(tail)

      [{:mov, [x, y]}, {:mov, [y, x]} | tail] ->
        IO.puts "movmov!"
        pass_pairs([{:mov, [x, y]} | tail])

      [op | tail] ->
        [op | pass_pairs(tail)]

      [] ->
        []
    end
  end

  def pass_knowns(assembly, knowledge) do
    case assembly do
      [{:mov, [x, y]} = op | tail] ->
        case what_is(knowledge, x) do
          {:ok, ^y} ->
            IO.puts "known mov!"
            pass_knowns(tail, knowledge)

          {:ok, z} ->
            IO.puts "possible!"
            [op | pass_knowns(tail, learn(knowledge, {x, :is, z}))]

          _ ->
            [op | pass_knowns(tail, learn(knowledge, {x, :is, y}))]
        end

      [{:ret, _} = op | tail] ->
        [op | pass_knowns(tail, forget_all())]

      [head | tail] ->
        [head | pass_knowns(tail, knowledge)]

      [] ->
        []
    end
  end

  defp what_is(knowledge, x) do
    at(knowledge, factsl() ~> matching({^x, :is, _}), fn {_, _, y} -> y end)
  end

  defp learn(%{facts: facts} = knowledge, {_, :is, _} = fact) do
    %{knowledge | facts: [fact | facts]}
  end

  defp forget_all() do
    %{facts: []}
  end

end
