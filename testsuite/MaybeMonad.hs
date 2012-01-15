-- Make Prop (a -> b) be transformed to a -> Prop b ?
-- Extensional equality only helps for plain proofs/fixpoint, but not to
-- do approximation lemma or induction
module MaybeMonad where

import AutoPrelude
import Prelude ()

data Maybe a = Just a | Nothing

(>>=) :: Maybe a -> (a -> Maybe b) -> Maybe b
Just x  >>= f = f x
Nothing >>= f = Nothing

return :: a -> Maybe a
return a = Just a

-- Bind -----------------------------------------------------------------------

prop_return_left :: Maybe a -> Prop (Maybe a)
prop_return_left m = (m >>= return) =:= m

prop_return_right :: (a -> Maybe b) -> a -> Prop (Maybe b)
prop_return_right f a = (return a >>= f) =:= f a

prop_assoc :: Maybe a -> (a -> Maybe b) -> (b -> Maybe c) -> Prop (Maybe c)
prop_assoc m f g = ((m >>= f) >>= g) =:= (m >>= (\x -> f x >>= g))

id x = x

fmap f m = m >>= (\x -> return (f x))

(f . g) x = f (g x)

-- Functor laws ---------------------------------------------------------------

prop_fmap_id :: Prop (Maybe a -> Maybe a)
prop_fmap_id = fmap id =:= id

--prop_fmap_id' :: Maybe a -> Prop (Maybe a)
--prop_fmap_id' m = fmap id m =:= id m

prop_fmap_comp :: (b -> c) -> (a -> b) -> Prop (Maybe a -> Maybe c)
prop_fmap_comp f g = fmap (f . g) =:= fmap f . fmap g

--prop_fmap_comp' :: (b -> c) -> (a -> b) -> Maybe a -> Prop (Maybe c)
--prop_fmap_comp' f g x = fmap (f . g) x =:= (fmap f . fmap g) x

-- Fmap / return law ----------------------------------------------------------
-- (return is a natural transformation)

prop_fmap_return :: (a -> b) -> Prop (a -> Maybe b)
prop_fmap_return f = return . f =:= fmap f . return

--prop_fmap_return' :: (a -> b) -> a -> Prop (Maybe b)
--prop_fmap_return' f x = (return . f) x =:= (fmap f . return) x

-- Monad laws in terms of join / fmap -----------------------------------------

join m = m >>= id

prop_join_fmap_join :: Prop (Maybe (Maybe (Maybe a)) -> Maybe a)
prop_join_fmap_join = join . fmap join =:= join . join

--prop_join_fmap_join' :: Maybe (Maybe (Maybe a)) -> Prop (Maybe a)
--prop_join_fmap_join' m = (join . fmap join) m =:= (join . join) m

prop_join_return :: Prop (Maybe a -> Maybe a)
prop_join_return = join . fmap return =:= join . return

--prop_join_return' :: Maybe a -> Prop (Maybe a)
--prop_join_return' m = (join . fmap return) m =:= (join . return) m

prop_join_return_id :: Prop (Maybe a -> Maybe a)
prop_join_return_id = join . return =:= id

--prop_join_return_id' :: Maybe a -> Prop (Maybe a)
--prop_join_return_id' m = (join . return) m =:= id m

prop_fmap_join :: (a -> b) -> Prop (Maybe (Maybe a) -> Maybe b)
prop_fmap_join f = join . fmap (fmap f) =:= fmap f . join

--prop_fmap_join' :: (a -> b) -> Maybe (Maybe a) -> Prop (Maybe b)
--prop_fmap_join' f m = (join . fmap (fmap f)) m =:= (fmap f . join) m


