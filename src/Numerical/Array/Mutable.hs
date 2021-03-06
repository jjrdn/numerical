
-- {-# LANGUAGE PolyKinds   #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ScopedTypeVariables#-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE FunctionalDependencies #-}


module Numerical.Array.Mutable(
    MArray(..)
    ,Array(..)
    ,RectilinearArray(..)
    ,DenseArrayBuilder(..)
    ,DenseArray(..)
    ,Boxed
    ,Unboxed
    ,Storable
    --,module Numerical.Array.Layout
    ,module Numerical.Array.Shape
    ) where

import Control.Monad.Primitive ( PrimMonad, PrimState )
--import qualified Numerical.Array.DenseLayout as L
import Numerical.Array.Address
import Numerical.Array.Layout
import Numerical.Array.Shape
--import Numerical.Nat
--import GHC.Prim(Constraint)
import Numerical.World
--import Numerical.Array.Range
--import Numerical.Array.Storage(Boxed,Unboxed,Stored)
--import Numerical.Array.Locality

import qualified Numerical.Array.Pure as A
import qualified Numerical.Array.Storage as S

--import qualified Data.Vector.Storable.Mutable as SM
--import qualified Data.Vector.Unboxed.Mutable as UM
--import qualified Data.Vector.Mutable as BM

{-
For now we're going to just crib the vector style api and Lift it
up into a multi dimensional setting.

the tentative design is to have something like



you'd think that the following array type is ``right''
but then you'll hit problems supporting
-}

-- data MArray world rep lay (view:: Locality) rank elm where
--      MArray
--          {_marrBuffer :: {-# UNPACK #!(MBuffer  world rep elm)
--          ,_marrForm :: {-# UNPACK #- } !(Form lay loc rank)
--          --,_marrShift :: {-# UNPACK #- } !Address
--          }


-- shift will be zero for most reps i'll ever care about, but in certain cases,
-- might not be. So for now not including it, but might be needed later,
-- though likely in regards to some sparse format of some sort.
--Omitting it for now, but may need to revisit later!
--
--For now any ``Address'' shift will need to be via the buffer
--
-- One ssue in the formats is ``logical'' vs ``manifest'' Address.
--
--
--we eedto have ``RepConstraint'' be decoupled from the type class instances
-- because we to sometimes have things that are world parametric
--
-- indexing should be oblivious to locality,



--NB: one important assumption we'll have for now, is that every


-- dsfdf
--type family RepConstraint world  rep el :: Constraint
--type instance MArrayElem

{- | 'MArray' is the generic data family that
-}
data family MArray world rep lay (view::Locality) (rank :: Nat ) st  el

data instance  MArray Native rep lay locality rank st el =
  MutableNativeArray {
          nativeBuffer  :: ! (S.BufferMut rep st el  )
          ,nativeFormat :: ! (Format lay locality rank rep)
    }


-- | Every 'MutableArray'  instance has a contiguous version
-- of itself, This contiguous version will ALWAYS have a Builder instance.
type family MutableArrayContiguous (marr :: * -> * -> *) :: * ->  * -> *
type instance  MutableArrayContiguous (MArray world rep layout locality rank)= MArray world rep layout Contiguous rank

-- | Sadly `ArrMutable` will have to have instances written by hand for now
-- May later migrate the freeze / thaw machinery to Array.Phased, but lets
type  family  ArrMutable ( arr :: * -> * )  :: * -> * -> *

class A.PureArray (ArrPure marr)  rank a => Array marr (rank:: Nat)  a | marr -> rank  where

    type   ArrPure (marr :: * -> * -> * ) :: * -> *

    -- the type of the underlying storage buffer
    type MutableArrayBuffer marr :: * -> * -> *

    -- really shouldnt appear in end user code, will only
    -- come up in writing new combinators
    -- the abstraction here is a reflection of the need for
    type MArrayAddress (marr :: * -> * -> * ) ::  *

    -- | 'basicUnsafeAffineAddressShift' is needed to handle abstracting acce
    basicUnsafeAffineAddressShift :: (address ~ MArrayAddress marr) => marr st a -> Int -> address -> address

    -- | Unsafely convert a mutable Array to its immutable version without copying.
    -- The mutable Array may not be used after this operation. Assumed O(1) complexity
    basicUnsafeFreeze :: (PrimMonad m, arr ~ ArrPure marr, marr ~ ArrMutable arr)
        => marr (PrimState m) a -> m (arr a)

    -- | Unsafely convert a pure Array to its mutable version without copying.
    -- the pure array may not be used after this operation. Assumed O(1) complexity
    basicUnsafeThaw :: (PrimMonad m, marr ~ ArrMutable arr, arr ~ ArrPure marr )
        => arr a -> m (marr (PrimState m) a)

    -- | gives the shape, a 'rank' length list of the dimensions
    basicShape :: marr st    a -> Index rank

    -- | 'basicCardinality' reports the number of manifest addresses/entries are
    -- in the array in a given address sub range.
    -- This is useful for determining when to switch from a recursive algorithm
    -- to a direct algorithm.
    basicCardinality ::(address ~ MArrayAddress marr) => marr st a -> Range address  -> Int

    --basicUnsafeRead  :: PrimMonad m => marr  (PrimState m)   a -> Shape rank Int -> m (Maybe a)

    --  | basicMutableSparseIndexToAddres checks if a index is present or not
    -- helpful primitive for authoring codes for (un)structured sparse array format
    basicSparseIndexToAddress :: (address ~ MArrayAddress marr)
      => marr s   a -> Index rank  ->  Maybe address

    -- | 'basicMutableAddressToIndex' assumes you only give it legal manifest addresses
    basicAddressToIndex :: (address ~ MArrayAddress marr) =>marr s   a -> address ->    Index rank

    -- |  return the smallest and largest valid logical address
    basicAddressRange :: (address ~ MArrayAddress marr)=> marr st   a ->  Maybe (Range address)



    ----  | return the largest valid logical adress
    --basicMaxAddress :: (address ~ MArrayAddress marr)=> marr st   a ->  address

    -- |  return the smallest valid array index
    --  should be weakly dominated by every other valid index
    -- basicMinIndex ::  marr st   a ->  Index rank
    -- basicMinIndex = \ marr -> basicAddressToIndex marr $ basicMinAddress marr
    -- {-# INLINE basicMinIndex #-}

    ---- | return the greatest valid array index
    ---- should weakly dominate every
    --basicMaxIndex ::  marr st  a -> Index rank
    --basicMaxIndex = \ marr -> basicAddressToIndex marr $ basicMaxAddress marr
    --{-# INLINE basicMaxIndex #-}


    -- | gives the next valid logical address
    -- undefined on invalid addresses and the greatest valid address.
    -- Note that for invalid addresses in between minAddress and maxAddress,
    -- will return the next valid address.

    basicSparseNextAddress :: (address ~ MArrayAddress marr)=> marr st  a -> address -> Maybe address


    -- I think the case could be made for a basicPreviousAddress opeeration

    -- | gives the next valid array index, the least valid index that is
    -- or
    basicSparseNextIndex ::(address ~ MArrayAddress marr)=>
         marr st  a ->  Index rank -> Maybe address  -> Maybe ( Index rank, address)





    -- | for a given valid address, @'basicAddressRegion' addr @ will return an AddressInterval
    -- that contains @addr@. This will be a singleton when the "maximal uniform stride interval"
    -- containing @addr@ has strictly less than 3 elements. Otherwise will return an Address range
    -- covering the maximal interval that will have cardinality at least 3.
    basicLocalAffineAddressRegion ::(address ~ MArrayAddress marr)
          => marr st a ->address ->  AffineRange address


    -- | this doesn't quite fit in this class, but thats ok, will deal with that later
    basicOverlaps :: marr st   a -> marr st   a -> Bool





    -- | Reset all elements of the vector to some undefined value, clearing all
    -- references to external objects. This is usually a noop for unboxed
    -- vectors. This method should not be called directly, use 'clear' instead.
    basicClear :: PrimMonad m => marr (PrimState m)   a -> m ()


    ---- | Yield the element at the given position. This method should not be
    ---- called directly, use 'unsafeRead' instead.
    basicUnsafeAddressRead  :: (PrimMonad m ,address ~ MArrayAddress marr) =>
        marr  (PrimState m)   a -> address-> m a

    ---- | Replace the element at the given position. This method should not be
    ---- called directly, use 'unsafeAddressWrite' instead.
    basicUnsafeAddressWrite :: (PrimMonad m ,address ~ MArrayAddress marr) =>
         marr  (PrimState m)   a -> address  -> a -> m ()



    --note  the sparsewrite and sparse read are "fused" versions of basicManifestAddress
    -- and address read and write. probably needs to be benchmarked! TODO

    -- | Yield the element at the given position. This method should not be
    -- called directly, use 'unsafeSparseRead' instead.
    basicUnsafeSparseRead :: PrimMonad m => marr  (PrimState m)   a ->
       Index rank -> m (Maybe a)

    -- | Replace the element at the given position. This method should not be
    -- called directly, use 'unsafeWrite' instead.
    basicUnsafeSparseWrite :: PrimMonad m => marr (PrimState m) a ->
      Index rank -> m( Maybe (a -> m ()))
-- this might get axed


{-
i think these *could* be derived
-}
{-
basicIndexedUpdateFoldM :: PrimMonad m => marr (PrimState m) rank a -> c ->
     (a->(Shape rank Int)-> c-> m (a,c) )-> m c


basicIndexedFoldM  :: PrimMonad m => marr (PrimState m) rank a -> c ->
     (a->(Shape rank Int)-> c-> m c )-> m c

basicIndexedMapM ::  PrimMonad m => marr (PrimState m) rank a ->
     (a->(Shape rank Int)-> m a )-> m ()
basicIndexedMapM_ ::  PrimMonad m => marr (PrimState m) rank a ->
     (a->(Shape rank Int)-> m () )-> m ()
basicIndexedMap

-}
--instance MutableArrayBuilder  (MArray NativeWorld ) where
--    func =




class ( Array marr rank a, A.PureDenseArray (ArrPure marr) rank a  )=>
            DenseArray marr rank a | marr -> rank   where
    -- | for Dense arrays, it is always easy to check if a given index is valid.
    -- this operation better have  O(1) complexity or else!
    basicIndexInBounds :: marr st a -> Index rank  -> Bool


    --basicUnsafeAddressDenseRead  :: PrimMonad m => marr  (PrimState m)   a -> Address-> m a

    -- i already have dense address indexing ?
    --basicUnsafeAddressDenseWrite :: PrimMonad m => marr  (PrimState m)   a -> Address -> a -> m ()

    -- | Yield the element at the given position. This method should not be
    -- called directly, use 'unsafeRead' instead.
    basicUnsafeDenseRead  :: PrimMonad m => marr  (PrimState m)   a -> Index rank -> m a

    -- | Replace the element at the given position. This method should not be
    -- called directly, use 'unsafeWrite' instead.
    basicUnsafeDenseWrite :: PrimMonad m => marr (PrimState m)   a -> Index rank   -> a -> m ()


    -- | gives the next valid logical address
    -- undefined on invalid addresses and the greatest valid address.
    -- Note that for invalid addresses in between minAddress and maxAddress,
    -- will return the next valid address.

    basicNextAddress ::  marr st  a -> Address ->  Address


    -- I think the case could be made for a basicPreviousAddress opeeration

    -- | gives the next valid array index
    -- undefined on invalid indices and the greatest valid index
    basicNextIndex :: marr st  a -> Index rank  -> Index rank







{-

Mutable (Dense) Array Builder will only have contiguous instances
and only makes sense for dense arrays afaik

BE VERY THOUGHTFUL about what instances you write, or i'll be mad


not including the general sparse building in the first release,
will include subsequently
-}

--class MutableArray marr (rank:: Nat) a => MutableArrayBuilder marr rank a where
    --basicBuildArray:: Index rank -> b

class DenseArray marr rank a => DenseArrayBuilder marr rank a where
    basicUnsafeNew :: PrimMonad m => Index rank -> m (marr (PrimState m)   a)
    basicUnsafeReplicate :: PrimMonad m => Index rank  -> a -> m (marr (PrimState m)  a)




class RectilinearArray marr rank a | marr -> rank   where

    -- | @'MutableRectilinearOrientation' marr@ should equal Row or Column for any sane choice
    -- of instance, because every MutableRectilinear instance will have a notion of
    -- what the nominal major axix will be.
    -- The intended use case is side condition constraints like
    -- @'MutableRectilinearOrientation' marr~Row)=> marr -> b @
    -- for operations where majorAxix projections are correct only for Row
    -- major formats. Such  as Row based forward/backward substitution (triangular solvers)
    type MutableRectilinearOrientation marr :: *

    type MutableArrayDownRank  marr ( st:: * ) a


    -- | MutableInnerContigArray is the "meet" (minimum) of the locality level of marr and InnerContiguous.
    -- Thus both Contiguous and InnerContiguous are made InnerContiguous, and Strided stays Strided
    -- for now this makes sense to have in the MutableRectilinear class, though that may change.
    -- This could also be thought of as being the GLB (greatest lower bound) on locality
    type MutableInnerContigArray (marr :: * ->  * -> *)  st  a



    --type MutableArrayBuffer
    --not implementing this .. for now

    -- | @'basicSliceMajorAxis' arr (x,y)@ returns the sub array of the same rank,
    -- with the outermost (ie major axis) dimension of arr restricted to the
    -- (x,y) is an inclusive interval, MUST satisfy x<y , and be a valid
    -- subinterval of the major axis of arr.
    basicMutableSliceMajorAxis :: PrimMonad m => marr (PrimState m)  a ->
      (Int,Int)-> m (marr (PrimState m)  a)
    --but  should it be primmonadic? nah, tis pure!

    --  |  semantically, 'basicProjectMajorAxis' arr ix, is the rank reducing version of what
    -- basicSliceMajorAxis arr (ix,ix) would mean _if_ the (ix,ix) tuple was a legal major axis slice
    basicMutableProjectMajorAxis :: PrimMonad m =>marr (PrimState m)  a
        -> Int -> m (MutableArrayDownRank marr (PrimState m)  a )

    -- | @'basicMutableSlice' arr ix1 ix2@  picks out the (hyper) rectangle in dimension @rank@
    -- where ix1 is the minimal corner and ix2
    basicMutableSlice :: PrimMonad m => marr (PrimState m)  a -> Index rank -> Index rank
        -> m (MutableInnerContigArray marr (PrimState m)  a )
