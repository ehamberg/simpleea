{-# Language BangPatterns #-}

{- |
Copyright    : 2010-2011 Erlend Hamberg
License      : BSD3
Stability    : experimental
Portability  : portable

A framework for simple evolutionary algorithms. Provided with a function for
evaluating a genome's fitness, a function for probabilistic selection among a
pool of genomes, and recombination and mutation operators, 'runEA' will run an
EA that lazily produces an infinite list of generations.

'AI.SimpleEA.Utils' contains utilitify functions that makes it easier to write
the genetic operators.

-}

module AI.SimpleEA (
    runEA
  , FitnessFunc
  , SelectionFunction
  , RecombinationOp
  , MutationOp
  , Fitness
  , Genome
  -- * Example Program
  -- $SimpleEAExample
) where

import Control.Monad.Random
import System.Random.Mersenne.Pure64

-- | An individual's fitness is simply a number.
type Fitness = Double

-- | A genome is a list (e.g. a 'String').
type Genome a = [a]

-- | A fitness functions assigns a fitness score to a genome. The rest of the
-- individuals of that generation is also provided in case the fitness is
-- in proportion to its neighbours.
type FitnessFunc a       = Genome a -> [Genome a] -> Fitness

-- | A selection function is responsible for selection. It takes pairs of
-- genomes and their fitness and is responsible for returning one or more
-- individuals.
type SelectionFunction a = [(Genome a, Fitness)] -> Rand PureMT [Genome a]

-- | A recombination operator takes two /parent/ genomes and returns two
-- /children/.
type RecombinationOp a = (Genome a, Genome a) -> Rand PureMT (Genome a, Genome a)

-- | A mutation operator takes a genome and returns (a possibly altered) copy
-- of it.
type MutationOp a = Genome a -> Rand PureMT (Genome a)

-- | Runs the evolutionary algorithm with the given start population. This will
-- produce an infinite list of generations and 'take' or 'takeWhile' should be
-- used to decide how many generations should be computed. To run a specific
-- number of generations, use 'take':
--
-- > let generations = take 50 $ runEA myFF mySF myROp myMOp myStdGen
--
-- To run until a criterion is met, e.g. that an individual with a fitness of at
-- least 19 is found, 'takeWhile' can be used:
--
-- > let criterion   = any id . map (\i -> snd i >= 19.0)
-- > let generations = takeWhile (not . criterion) $ runEA myFF mySF myROp myMOp myStdGen


runEA ::
  [Genome a] ->
  FitnessFunc a ->
  SelectionFunction a ->
  RecombinationOp a ->
  MutationOp a ->
  PureMT ->
  [[(Genome a,Fitness)]]
runEA startPop fitFun selFun recOp mutOp g =
  let p = zip startPop (map (`fitFun` startPop) startPop)
  in evalRand (generations p selFun fitFun recOp mutOp) g

generations ::
  [(Genome a, Fitness)] ->
  SelectionFunction a ->
  FitnessFunc a ->
  RecombinationOp a ->
  MutationOp a ->
  Rand PureMT [[(Genome a, Fitness)]]
generations !pop selFun fitFun recOp mutOp = do
    -- first, select parents for the new generation
    newGen <- selFun pop

    -- then create offspring by using the recombination operator
    newGen  <- doRecombinations newGen recOp

    -- mutate genomes using the mutation operator
    newGen <- mapM mutOp newGen

    let fitnessVals = map (`fitFun` newGen) newGen
    nextGens <- generations (zip newGen fitnessVals) selFun fitFun recOp mutOp

    return $ pop : nextGens

doRecombinations :: [Genome a] -> RecombinationOp a -> Rand PureMT [Genome a]
doRecombinations []      _   = return []
doRecombinations [_]     _   = error "odd number of parents"
doRecombinations (a:b:r) rec = do
    (a',b') <- rec (a,b)
    rest    <- doRecombinations r rec
    return $ a':b':rest

{- $SimpleEAExample

The aim of this /OneMax/ EA is to maximize the number of @1@'s in a bitstring.
The fitness of a
bitstring i simply s defined to be the number of @1@'s it contains.

>import AI.SimpleEA
>import AI.SimpleEA.Utils
>
>import System.Random.Mersenne.Pure64
>import Control.Monad.Random
>import Data.List
>import System.Environment (getArgs)
>import Control.Monad (unless)

The @numOnes@ function will function as our 'FitnessFunc' and simply returns
the number of @1@'s in the string. It ignores the rest of the population (the
second parameter) since the fitness is not relative to the other individuals in
the generation.

>numOnes :: FitnessFunc Char
>numOnes g _ = (fromIntegral . length . filter (=='1')) g

The @select@ function is our 'SelectionFunction'. It uses sigma-scaled,
fitness-proportionate selection. 'sigmaScale' is defined in
'AI.SimpleEA.Utils'. By first taking the four best genomes (by using the
@elite@ function) we make sure that maximum fitness never decreases
('elitism').

>select :: SelectionFunction Char
>select gs = select' (take 4 $ elite gs)
>    where scaled = zip (map fst gs) (sigmaScale (map snd gs))
>          select' gs' =
>              if length gs' >= length gs
>                 then return gs'
>                 else do
>                     p1 <- fitPropSelect scaled
>                     p2 <- fitPropSelect scaled
>                     let newPop = p1:p2:gs'
>                     select' newPop

Crossover is done by finding a crossover point along the length of the genomes
and swapping what comes after that point between the two genomes. The parameter
@p@ determines the likelihood of crossover taking place.

>crossOver :: Double -> RecombinationOp Char
>crossOver p (g1,g2) = do
>    t <- getRandomR (0.0, 1.0)
>    if t < p
>       then do
>           r <- getRandomR (0, length g1-1)
>           return (take r g1 ++ drop r g2, take r g2 ++ drop r g1)
>       else return (g1,g2)

The mutation operator @mutate@ flips a random bit along the length of the
genome with probability @p@.

>mutate :: Double -> MutationOp Char
>mutate p g = do
>    t <- getRandomR (0.0, 1.0)
>    if t < p
>       then do
>           r <- getRandomR (0, length g-1)
>           return (take r g ++ flipBit (g !! r) : drop (r+1) g)
>       else return g
>        where
>              flipBit '0' = '1'
>              flipBit '1' = '0'

The @main@ function creates a list of 100 random genomes (bit-strings) of length
20 and then runs the EA for 100 generations (101 generations including the
random starting population). Average and maximum fitness values and standard
deviation is then calculated for each generation and written to a file if a file
name was provided as a parameter. This data can then be plotted with, e.g.
gnuplot (<http://www.gnuplot.info/>).

>main = do
>    args <- getArgs
>    g <- newPureMT
>    let (p,g') = runRand (randomGenomes 100 20 '0' '1') g
>    let gs = take 101 $ runEA p numOnes select (crossOver 0.75) (mutate 0.01) g'
>    let fs = avgFitnesses gs
>    let ms = maxFitnesses gs
>    let ds = stdDeviations gs
>    mapM_ print $ zip5 gs [1..] fs ms ds
>    unless (null args) $ writeFile (head args) $ getPlottingData gs

-}
