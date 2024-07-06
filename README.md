# CodeEvaluation

[![Build Status](https://github.com/JuliaDocs/CodeEvaluation.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaDocs/CodeEvaluation.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CodeEvaluation.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CodeEvaluation.html)

A small utility package to emulate executing Julia code, seemingly in a clean `Main` module.

> [!NOTE]
> This package is in active development.

## API overview

There are two main parts to the API:

1. The `Sandbox` object: provides a clean, mock Julia Main module, and the related low-level `evaluate!` function to directly evaluate Julia expressions in the sandbox.

2. Higher level functions that can be used to run code in the sandbox in different modes (`codeblock!` and `replblock!`).

> [!NOTE]
> The functions that run code in a sandbox are marked with `!` because they mutate the sandbox.

> [!WARNING]
> The code evaluation is not thread/async-safe.
> For each evaluation, the code has to change the Julia process' working directory with `cd`.
> This also affects any code running in parallel in other tasks or threads.

> [!NOTE]
> This is just a high-level overview.
> See the docstrings for more details!

### Sandbox

Constructing a `Sandbox` object provides you

The `evaluate!` function can be used to evaluate Julia expressions within the context of the sandbox module.
It returns a `Result` object that contains the captured return value and what was printed into the standard output and error streams.

```julia-repl
julia> sb = CodeEvaluation.Sandbox();

julia> r = CodeEvaluation.evaluate!(sb, :(x = 40 + 2));

julia> r.value, r.output
(42, "")

julia> r = CodeEvaluation.evaluate!(sb, :(println("x = " * string(x))));

julia> r.value, r.output
(nothing, "x = 42\n")
```

As an implementation detail, it uses the [IOCapture.jl](https://github.com/JuliaDocs/IOCapture.jl) package underneath to perform output capture of the evaluated code.

As an asterisk, as the sandboxes are implemented as anonymous Julia modules, all within the same Julia process, there are limitations to to their independence (e.g. method definitions and other global state modifications can, of course, leak over).
The goal is to be best-effort in terms of providing a seemingly independent Julia session to execute code in.

> [!NOTE]
> The notion of a sandbox can probably be abstracted.
> While a module-based sandbox is very simple, it would be useful to have a way to execute Julia code in a clean process (e.g. to fully enforce the independence of the sandboxes, run code in a different package environment, or multi-threading settings).
> However, ideally the high-level API would be the same, irrespective of how the sandbox is implemented.

### Evaluating code

Presently, there are two functions that offer a

1. `codeblock!` is meant to offer a simple way to execute a block of Julia code (provided as a simple string, not a parsed expression).
   This is roughly meant to correspond to running a Julia script.

   ```julia-repl
   julia> sb = CodeEvaluation.Sandbox();

   julia> code = """
          x = 40
          println("x = \$x")
          x + 2
          """
   "x = 40\nprintln(\"x = \$x\")\nx + 2\n"

   julia> r = CodeEvaluation.codeblock!(sb, code);

   julia> r.value, r.output
   (42, "x = 40\n")
   ```

2. `replblock!` emulates a REPL session.
   The input code is split up and evaluated as if copy-pasted into the REPL line-by-line.
   The outputs are then captured as if they would be shown in the REPL.

   ```julia-repl
   julia> sb = CodeEvaluation.Sandbox();

   julia> code = """
          x = 40
          println("x = \$x")
          x + 2
          """
   "x = 40\nprintln(\"x = \$x\")\nx + 2\n"

   julia> r = CodeEvaluation.replblock!(sb, code);
   ```

   At this point, using the `CodeEvaluation.join_to_string(r)` function, the package is able to reconstruct how the corresponding REPL session would look like.

   ```julia-repl
   julia> x = 40
   40

   julia> println("x = $x")
   x = 40

   julia> x + 2
   42
   ```

> [!NOTE]
> Additional code evaluation "modes" could be added as new functions --- the precise requirements differ, so it would be useful to have a library of methods available.
