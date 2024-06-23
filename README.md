# CodeEvaluation

[![Build Status](https://github.com/JuliaDocs/CodeEvaluation.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaDocs/CodeEvaluation.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CodeEvaluation.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CodeEvaluation.html)

> [!NOTE]
> This package is in active development, and not yet registered.

A small utility package to emulate executing Julia code in a clean `Main` module.
Underneath, it uses [IOCapture.jl](https://github.com/JuliaDocs/IOCapture.jl) to perform output capture of the evaluated code.

> [!WARNING]
> The code evaluation is not thread/async-safe.
> For each evaluation, the code has to change the Julia process' working directory with `cd`.
> This also affects any code running in parallel in other tasks or threads.
