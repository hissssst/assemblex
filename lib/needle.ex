defmodule Needle do

  import Assemblex, only: [asm: 1, nasm: 1]

  def test do
    nasm [
      asm do
               global    main
               extern    printf
               section   .text

          main nop
      end,
      gen_for_expression(quote(do: 1 + 2 + 3)),
      asm do
               mov       rdi, format
               mov       rsi, rax
               xor       rax, rax
               call      printf

               xor       rax, rax
               ret
      end,
      gen_plus(),
      gen_mult(),
      gen_minus(),
      asm do
        format db "Hey %d", 10, 0
      end,
    ]
  end

  defp arg_to_reg([]), do: %{}
  defp arg_to_reg([a1]), do: %{a1 => :rdi}
  defp arg_to_reg([a1, a2]), do: %{a1 => :rdi, a2 => :rsi}

  defp registers([]), do: %{}
  defp registers([_]), do: [:rdi]
  defp registers([_, _]), do: [:rdi, :rsi]

  def gen_func(name, args, body) do
    arg_to_reg =
      args
      |> Enum.map(fn {name, _, _} -> name end)
      |> arg_to_reg()

    body = Macro.prewalk(body, fn
      {argname, _, ctx} when is_atom(ctx) ->
        %{^argname => reg} = arg_to_reg
        reg

      other ->
        other
    end)

    gen_function(name, registers(args), gen_for_expression(body))
  end

  def gen_for_expression(ast) do
    case ast do
      {op, _, [l, r]} when op in ~w[+ * -]a ->
        l = gen_for_expression(l)
        r = gen_for_expression(r)
        [
          l,
          asm do
            push rbx
            mov rbx, rax
          end,
          r,
          asm do
            mov rdi, rbx
            mov rsi, rax
            pop rbx
          end,
          case op do
            :"+" -> asm(call plus)
            :"-" -> asm(call minus)
            :"*" -> asm(call mult)
          end
        ]

      {:printf, _, [arg]} ->
        [
          gen_for_expression(arg),
          asm do
            mov       rdi, format
            mov       rsi, rax
            xor       rax, rax
            call      printf
          end
        ]

      {func, _, args} when is_list(args)  ->
        [
          for arg <- args do
            asm do
              unescape(gen_for_expression(arg))
              push rax
            end
          end,
          for reg <- :lists.reverse(registers(args)) do
            {:pop, [reg]}
          end,
          {:call, [func]}
        ]
        
      other ->
        asm(mov rax, unescape(other))
    end
  end

  defp gen_minus() do
    gen_function(:minus, [:rdi, :rsi], asm do
       sub   rdi, rsi
       mov   rax, rdi
    end)
  end
  
  defp gen_mult() do
    gen_function(:mult, [:rdi, :rsi], asm do
       imul  rdi, rsi
       mov   rax, rdi
    end)
  end

  defp gen_plus() do
    gen_function(:plus, [:rdi, :rsi], asm do
       add   rdi, rsi
       mov   rax, rdi
    end)
  end

  defp gen_function(name, args_registers, body) do
    [
      {name, :nop, []},
      Enum.map(args_registers, & {:push, [&1]}),
      body,
      :lists.reverse(Enum.map(args_registers, & {:pop, [&1]})),
      {:ret, []}
    ]
  end

  ### ====================================================================

  defmacro language(do: {:__block__, _, defs}) do
    funcs =
      Enum.map(defs, fn {:func, _, [{name, _, args}, [do: body]]} ->
        gen_func(name, args, body)
      end)

    IO.inspect List.flatten(funcs), label: :funcs

    assembly = Macro.escape List.flatten [
      asm do
               global    main
               extern    printf
               section   .text
      end,
      funcs,
      gen_plus(),
      gen_mult(),
      gen_minus(),
      asm do
        format db "Hey %d", 10, 0
      end,
    ]

    assembly
  end

  def test2() do
    assembly =
      language do
        func main() do
          printf(subsub(5, 2))
        end

        func subsub(x, y) do
          x * x + y * y
        end

        func square(x) do
          x * x
        end
      end

    nasm assembly
  end
  
end
