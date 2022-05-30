defmodule Assemblex do

  @moduledoc """
  Like NASM but inside Elixir
  """

  @doc """
  Translates elixir asm to string
  """
  def translate(commands) do
    commands = List.flatten(commands)

    maxlabel_length =
      Enum.reduce(commands, 0, fn
        {label, _, _}, acc -> max(String.length("#{label}"), acc)
        _, acc -> acc
      end)

    commands
    |> Enum.map(fn
      {name, args} ->
        argstr = Enum.join(List.wrap(args), ", ")
        "#{name} #{argstr}"
        
      {label, name, args} ->
        argstr = Enum.join(List.wrap(args), ", ")
        "#{label}: #{name} #{argstr}"
    end)
    |> Enum.join("\n")
  end

  def nasm(string) when is_binary(string) do
    IO.puts string
    filename = "assemblex_#{DateTime.to_unix DateTime.utc_now()}"
    tmpfilename = "/tmp/#{filename}"
    File.write!(tmpfilename, string)
    with(
      {_, 0} <- System.cmd("nasm", ["-felf64", tmpfilename]),
      {_, 0} <- System.cmd("gcc", [tmpfilename <> ".o"])
    ) do
      System.cmd("#{File.cwd!()}/a.out", [])
    end
  end
  def nasm(commands), do: nasm translate commands

  defp args_to_list(nil), do: []
  defp args_to_list({:unescape, _, [inner]}), do: inner
  defp args_to_list(args), do: Enum.map(args, &arg_to_list/1)

  defp arg_to_list({:unescape, _, [inner]}), do: inner
  defp arg_to_list({arg, _, nil}), do: arg
  # defp arg_to_list({:dword, _, [[memory]]}), do: "dword "
  defp arg_to_list(string) when is_binary(string), do: "\"#{string}\""
  defp arg_to_list({:"<<>>", _, _} = s), do: quote(do: "\"" <> unquote(s) <> "\"")
  defp arg_to_list(other), do: other

  defp unblock({:__block__, _, block}), do: List.wrap(block)
  defp unblock(block), do: List.wrap(block)

  defp section_block(block) do
    Enum.map(unblock(block), fn
      {:unescape, _, [inner]} ->
        inner

      {label, _, [{op, _, args}]} when is_list(args) ->
        {:"{}", [], [label, op, args_to_list(args)]}

      {{:".", _, [{:section, _, _}, name]}, _, _} ->
        {:section, ".#{name}"}

      {op, _, args} ->
        {op, args_to_list(args)}
    end)
    |> tap(fn x -> IO.puts Macro.to_string x end)
  end

  defmacro asm(do: block), do: section_block(block)
  defmacro asm(block), do: section_block(block)

  def helloworld() do
    printf = 60
    call = asm(do: syscall)
    nasm [
      asm do
        global  _start
        section .text
        _start  mov     rax, 1
                mov     rdi, 1
                mov     rsi, message
                mov     rdx, 13
                unescape(call)
                mov     rax, unescape(printf)
                xor     rdi, rdi
                # mov     esi, dword [result]
                syscall

        unescape [
          asm do
            section .data
            message db "Hello world!", 10
          end
        ]
      end
    ]
  end

  def hello() do
    nasm [
      asm do
             global    main
             extern    printf
             section   .text

        main mov       rdi, message
             mov       rsi, 1
             xor       rax, rax
             call      printf
             ret

        message db "Hello %d!", 0
      end
    ]
  end

  def hello_old(name) do
    nasm [
      asm do
             global    main
             extern    puts
             section   .text

        main mov       rdi, message
             call      puts
             ret

        message db "Hello #{name}!", 0
      end
    ]
  end

end
