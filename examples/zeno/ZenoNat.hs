{-# LANGUAGE FlexibleInstances, ScopedTypeVariables, ExistentialQuantification #-}

-- All Nat properties of Zeno, that don't use given

module ZenoNoTC where

import Prelude ()
-- import Zeno

data Bool = True | False

infix 1 :=:

-- infixr 0 $
-- ($) :: (a -> b) -> a -> b
-- f $ x = f x

otherwise :: Bool
otherwise = True

data Equals a = (:=:) a a

data Prop a
  = Prove (Equals a)
--  | Given Equals Prop

prove :: Equals a -> Prop a
prove x = Prove x

-- given :: Equals -> Prop -> Prop
-- given x p = Given x p

proveBool :: Bool -> Prop Bool
proveBool p = Prove (p :=: True)

-- givenBool :: Bool -> Prop -> Prop
-- givenBool p = Given (p :=: True)

data Nat = Z | S Nat

-- Boolean functions

not :: Bool -> Bool
not True = False
not False = True

(&&) :: Bool -> Bool -> Bool
True && True = True
_    && _    = False


-- Natural numbers

Z     == Z     = True
Z     == _     = False
(S _) == Z     = False
(S x) == (S y) = x == y

Z     <= _     = True
_     <= Z     = False
(S x) <= (S y) = x <= y

_     < Z     = False
Z     < _     = True
(S x) < (S y) = x < y

Z     + y = y
(S x) + y = S (x + y)

Z     - _     = Z
x     - Z     = x
(S x) - (S y) = x - y

Z     * _ = Z
(S x) * y = y + (x * y)

min Z     _     = Z
min (S x) Z     = Z
min (S x) (S y) = S (min x y)

max Z     y     = y
max x     Z     = x
max (S x) (S y) = S (max x y)

prop_zero_is_one :: Prop Nat
prop_zero_is_one = prove (Z :=: S Z)

prop_refl :: Nat -> Prop Bool
prop_refl x
  = proveBool (x == x)

prop_assoc_plus :: Nat -> Nat -> Nat -> Prop Nat
prop_assoc_plus x y z
  = prove (x + (y + z) :=: (x + y) + z)

prop_assoc_mul :: Nat -> Nat -> Nat -> Prop Nat
prop_assoc_mul x y z
  = prove (x * (y * z) :=: (x * y) * z)

prop_id :: Nat -> Prop Nat
prop_id x = prove (x :=: x)

prop_right_identity_plus :: Nat -> Prop Nat
prop_right_identity_plus x
  = prove (x + Z :=: x)

prop_left_identity_plus :: Nat -> Prop Nat
prop_left_identity_plus x
  = prove (Z + x :=: x)

prop_right_identity_mul :: Nat -> Prop Nat
prop_right_identity_mul x
  = prove (x * S Z :=: x)

prop_left_identity_mul :: Nat -> Prop Nat
prop_left_identity_mul x
  = prove (S Z * x :=: x)

prop_add_comm :: Nat -> Nat -> Prop Nat
prop_add_comm x y
  = prove (x + y :=: y + x)

prop_mul_comm :: Nat -> Nat -> Prop Nat
prop_mul_comm x y
  = prove (x * y :=: y * x)

prop_left_distrib :: Nat -> Nat -> Nat -> Prop Nat
prop_left_distrib x y z
  = prove (x * (y + z) :=: (x * y) + (x * z))

prop_right_distrib :: Nat -> Nat -> Nat -> Prop Nat
prop_right_distrib x y z
  = prove ((x + y) * z :=: (x * z) + (y * z))

prop_min_absorb :: Nat -> Nat -> Prop Nat
prop_min_absorb x y
  = prove (min x (max x y) :=: x)

prop_max_absorb :: Nat -> Nat -> Prop Nat
prop_max_absorb x y
  = prove (max x (min x y) :=: x)

prop_idem_plus :: Nat -> Prop Nat
prop_idem_plus x
  = prove (x + x :=: x)

prop_idem_mul :: Nat -> Prop Nat
prop_idem_mul x
  = prove (x * x :=: x)

prop_06 :: Nat -> Nat -> Prop Nat
prop_06 n m
  = prove (n - (n + m) :=: Z)

prop_07  :: Nat -> Nat -> Prop Nat
prop_07 n m
  = prove ((n + m) - n :=: m)

prop_08 :: Nat -> Nat -> Nat -> Prop Nat
prop_08 k m n
  = prove ((k + m) - (k + n) :=: m - n)

prop_09 :: Nat -> Nat -> Nat -> Prop Nat
prop_09 i j k
  = prove ((i - j) - k :=: i - (j + k))

prop_10 :: Nat -> Prop Nat
prop_10 m
  = prove (m - m :=: Z)

prop_17 :: Nat -> Prop Bool
prop_17 n
  = prove (n <= Z :=: n == Z)

prop_18 :: Nat -> Nat -> Prop Bool
prop_18 i m
  = proveBool (i < S (i + m))

prop_21 :: Nat -> Nat -> Prop Bool
prop_21 n m
  = proveBool (n <= (n + m))

prop_22 :: Nat -> Nat -> Nat -> Prop Nat
prop_22 a b c
  = prove (max (max a b) c :=: max a (max b c))

prop_23 :: Nat -> Nat -> Prop Nat
prop_23 a b
  = prove (max a b :=: max b a)

prop_24 :: Nat -> Nat -> Prop Bool
prop_24 a b
  = prove ((max a b) == a :=: b <= a)

prop_25 :: Nat -> Nat -> Prop Bool
prop_25 a b
  = prove ((max a b) == b :=: a <= b)

prop_31 :: Nat -> Nat -> Nat -> Prop Nat
prop_31 a b c
  = prove (min (min a b) c :=: min a (min b c))

prop_32 :: Nat -> Nat -> Prop Nat
prop_32 a b
  = prove (min a b :=: min b a)

prop_33 :: Nat -> Nat -> Prop Bool
prop_33 a b
  = prove (min a b == a :=: a <= b)

prop_34 :: Nat -> Nat -> Prop Bool
prop_34 a b
  = prove (min a b == b :=: b <= a)

prop_54 :: Nat -> Nat -> Prop Nat
prop_54 n m
  = prove ((m + n) - n :=: m)

prop_65  :: Nat -> Nat -> Prop Bool
prop_65 i m =
  proveBool (i < S (m + i))

prop_69 :: Nat -> Nat -> Prop Bool
prop_69 n m
  = proveBool (n <= (m + n))

{-
prop_70 m n
  = givenBool (m <= n)
  $ proveBool (m <= S n)
-}

prop_79 :: Nat -> Nat -> Nat -> Prop Nat
prop_79 m n k
  = prove ((S m - n) - S k :=: (m - n) - k)

