# gopher-lua Benchmark Assets

This directory contains a Lua program which may be fed into the benchmark
application for gopher-lua.

The Lua program in this directory, k-nucleotide, is a toy application taken
from The Computer Language Benchmarks Game and is licensed under a
BSD-3-clause license, which may be found in this directory. It was taken mostly
in its original form, with minor modifications.

Although a toy application, this represents a reasonably good end-to-end
benchmark for a Lua VM.

The input to the k-nucleotide script (the "seq" parameter) is derived from the
file `input.txt` which contains a randomly generated nucleotide sequence,
generated using the Go `fasta` benchmark from The Computer Language Benchmark
Game. See [this
page](https://benchmarksgame-team.pages.debian.net/benchmarksgame/program/fasta-go-3.html)
for more details.
