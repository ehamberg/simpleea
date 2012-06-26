`SimpleEA` is a Haskell library for evolutionary algorithms. It is written to be
easy to understand and use.

A simple example program using the library is included in `AI/SimpleEA.hs`. The
documentation is also [available at
Hackage](http://hackage.haskell.org/package/SimpleEA).

Given a function for evaluating a genome's fitness, a function for probabilistic
selection among a pool of genomes, and recombination and mutation operators, an
infinite list of generations is produced. You can choose to `take` a predefined
number of these generations or `takeWhile` a predicate holds (e.g. that the
fitness is below some value).

Utility functions for analyzing a run and for producing plotting data is
included in `AI/SimpleEA/Utils.hs`.
