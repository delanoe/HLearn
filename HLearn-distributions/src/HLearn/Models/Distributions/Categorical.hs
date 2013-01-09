{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE BangPatterns #-}


-- | The categorical distribution is used for discrete data.  It is also sometimes called the discrete distribution or the multinomial distribution.  For more, see the wikipedia entry: <https://en.wikipedia.org/wiki/Categorical_distribution>
module HLearn.Models.Distributions.Categorical
    ( 
    -- * Data types
    Categorical (..)
    , CategoricalParams(..)
    
    -- * Helper functions
    , dist2list
    , mostLikely
    )
    where

import Control.DeepSeq
import Control.Monad.Random
import Data.List
import Data.List.Extras
import Debug.Trace

import qualified Data.Map.Strict as Map
import qualified Data.Foldable as F

import HLearn.Algebra
import HLearn.Models.Distributions.Common

-------------------------------------------------------------------------------
-- CategoricalParams

-- | The Categorical distribution takes no parameters
data CategoricalParams = CategoricalParams
    deriving (Read,Show,Eq,Ord)

instance NFData CategoricalParams where
    rnf x = ()

instance Model CategoricalParams (Categorical label probtype) where
    getparams model = CategoricalParams

instance DefaultModel CategoricalParams (Categorical label probtype) where
-- instance DefaultModel CategoricalParams (Categorical Int Double) where
    defparams = CategoricalParams

-------------------------------------------------------------------------------
-- Categorical

data Categorical sampletype probtype = Categorical 
        { pdfmap :: !(Map.Map sampletype probtype)
        } 
    deriving (Show,Read,Eq,Ord)


instance (NFData sampletype, NFData probtype) => NFData (Categorical sampletype probtype) where
    rnf d = rnf $ pdfmap d

-------------------------------------------------------------------------------
-- Training

instance (Ord label, Num probtype) => HomTrainer CategoricalParams label (Categorical label probtype) where
    train1dp' params dp = Categorical $ Map.singleton dp 1

-------------------------------------------------------------------------------
-- Distribution

instance (Ord label, Ord prob, Fractional prob, Random prob) => Distribution (Categorical label prob) label prob where

    {-# INLINE pdf #-}
    pdf dist label = {-0.0001+-}(val/tot)
        where
            val = case Map.lookup label (pdfmap dist) of
                Nothing -> 0
                Just x  -> x
            tot = F.foldl' (+) 0 $ pdfmap dist

{-    {-# INLINE cdf #-}
    cdf dist label = (Map.foldl' (+) 0 $ Map.filterWithKey (\k a -> k<=label) $ pdfmap dist) 
                   / (Map.foldl' (+) 0 $ pdfmap dist)
                   
    {-# INLINE cdfInverse #-}
    cdfInverse dist prob = go prob pdfL
        where
            pdfL = map (\k -> (k,pdf dist k)) $ Map.keys $ pdfmap dist
            go prob []     = fst $ last pdfL
            go prob (x:xs) = if prob < snd x && prob > (snd $ head xs)
                then fst x
                else go (prob-snd x) xs
--     cdfInverse dist prob = argmax (cdf dist) $ Map.keys $ pdfmap dist

    {-# INLINE mean #-}
    mean dist = fst $ argmax snd $ Map.toList $ pdfmap dist

    {-# INLINE drawSample #-}
    drawSample dist = do
        x <- getRandomR (0,1)
        return $ cdfInverse dist (x::prob)
-}

-- | Extracts the element in the distribution with the highest probability
mostLikely :: Ord prob => Categorical label prob -> label
mostLikely dist = fst $ argmax snd $ Map.toList $ pdfmap dist

-- | Converts a distribution into a list of (sample,probability) pai
dist2list :: Categorical sampletype probtype -> [(sampletype,probtype)]
dist2list (Categorical pdfmap) = Map.toList pdfmap

-------------------------------------------------------------------------------
-- Algebra

instance (Ord label, Num probtype{-, NFData probtype-}) => Abelian (Categorical label probtype)
instance (Ord label, Num probtype{-, NFData probtype-}) => Semigroup (Categorical label probtype) where
    (<>) !d1 !d2 = {-deepseq res $-} Categorical $ res
        where
            res = Map.unionWith (+) (pdfmap d1) (pdfmap d2)

instance (Ord label, Num probtype) => RegularSemigroup (Categorical label probtype) where
    inverse d1 = d1 {pdfmap=Map.map (0-) (pdfmap d1)}

instance (Ord label, Num probtype) => Monoid (Categorical label probtype) where
    mempty = Categorical Map.empty
    mappend = (<>)

-- instance (Ord label, Num probtype) => Group (Categorical label probtype)

instance (Ord label, Num probtype) => LeftModule probtype (Categorical label probtype)
instance (Ord label, Num probtype) => LeftOperator probtype (Categorical label probtype) where
    p .* (Categorical pdf) = Categorical $ Map.map (*p) pdf

instance (Ord label, Num probtype) => RightModule probtype (Categorical label probtype)
instance (Ord label, Num probtype) => RightOperator probtype (Categorical label probtype) where
    (*.) = flip (.*)

-------------------------------------------------------------------------------
-- Morphisms

instance 
    ( Ord label
    , Num probtype
    ) => Morphism (Categorical label probtype) FreeModParams (FreeMod probtype label) 
        where
    Categorical pdf $> FreeModParams = FreeMod pdf