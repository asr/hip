{-# LANGUAGE FlexibleInstances,GeneralizedNewtypeDeriving,TypeSynonymInstances #-}
module Language.TPTP.Monad (module Language.TPTP
                           ,M
                           ,run
                           ,newVar
                           ,constant
                           ,unary
                           ,binary
                           ,predicate
                           ,relation
                           ,(==>),(&),(/\),(\/),(<=>)
                           ,(===),(!=)
                           ,axiom
                           ,conjecture
                           ,forall
                           ,exists
                           ) where

import Data.Map (Map)
import qualified Data.Map as M
import Control.Monad
import Control.Monad.State
import Control.Applicative hiding (empty)
import Control.Arrow (first,second,(***))

import Language.TPTP hiding ((===),(!=),(&),(/\),(\/),(==>),(<=>),mkBinOp)

type ST = [VarName]

newtype M a = M { runM :: State ST a }
  deriving (Monad,MonadState ST,Functor,Applicative)

run :: M a -> a
run m = evalState (runM m) vars
  where vars = [ VarName ("X" ++ show x) | x <- [0..] ]

newVar :: M VarName
newVar = do
  v:vs <- get
  put vs
  return v

constant :: String -> M Term
constant n = return (Fun (FunName n) [])

unary :: String -> M Term -> M Term
unary n = liftM (Fun (FunName n) . pure)

binary :: String -> M Term -> M Term -> M Term
binary n = liftM2 (\x y -> Fun (FunName n) [x,y])

predicate :: String -> M Term -> M Formula
predicate n = liftM (Rel (RelName n) . pure)

relation :: String -> M Term -> M Term -> M Formula
relation n = liftM2 (\x y -> Rel (RelName n) [x,y])

mkBinOp :: BinOp
        -> M Formula -> M Formula -> M Formula
mkBinOp op = liftM2 (\f g -> BinOp f op g)

infix 4 ===
infix 4 !=
infixr 3 &
infixr 3 /\
infixr 2 \/
infixl 1 ==>
infix  1 <=>

(==>) = mkBinOp (:=>)
(&)   = mkBinOp (:&)
(/\)  = mkBinOp (:&)
(\/)  = mkBinOp (:|)
(<=>) = mkBinOp (:<=>)

(===),(!=) :: M Term -> M Term -> M Formula
(===) = liftM2 (\f g -> EqOp f (:==) g)
(!=)  = liftM2 (\f g -> EqOp f (:!=) g)


axiom :: String -> M Formula -> Decl
axiom s f = Axiom s (run f)

conjecture :: String -> M Formula -> Decl
conjecture s f = Conjecture s (run f)

class Quantifier t where
    quantifier
        :: ([VarName] -> Formula -> Formula) -- ^ quantifier, Forall or Exists
        -> [VarName]                         -- ^ accumulated used variables
        -> t                                 -- ^ Formula or (Term -> t)
        -> M Formula                         -- ^ resulting formula

instance Quantifier (M Formula) where
    quantifier q acc f = q (reverse acc) <$> f

instance Quantifier r => Quantifier (M Term -> r) where
    quantifier q acc f = newVar >>= \v -> quantifier q (v:acc) (f (return (Var v)))

forall :: (Quantifier t) => t -> M Formula
forall = quantifier Forall []

exists :: (Quantifier t) => t -> M Formula
exists = quantifier Exists []
