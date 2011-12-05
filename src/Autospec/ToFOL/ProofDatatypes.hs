{-# LANGUAGE DeriveFunctor #-}
module Autospec.ToFOL.ProofDatatypes where

import qualified Language.TPTP as T
import Autospec.ToFOL.Core

proofDatatypes :: [Name]
proofDatatypes = ["Prop"]

proveFunctions :: [Name]
proveFunctions = ["prove","proveBool","given","givenBool","=:=","=/="]

provable :: Expr -> Bool
provable (App f es) = f `elem` proveFunctions || any provable es
provable _          = False

data ProofType = Plain
               | SimpleInduction       { indVar :: Name }
               | ApproxLemma
               | FixpointInduction     { fixFun :: Name }
  deriving (Eq,Ord)

data Failure = Fail          -- ^ If this property fails, then the whole proof techinque fails
             | InfiniteFail  -- ^ If this property fails, it's just the infinite case that fails
             | EpicFail      -- ^ If this property is Countersatisfiable, then the conjecture fails
  deriving (Eq,Ord,Show)

instance Show ProofType where
  show Plain                 = "plain"
  show (SimpleInduction v)   = "simple induction on " ++ v
  show ApproxLemma           = "approximation lemma"
  show (FixpointInduction f) = "fixed point induction on " ++ f

proofTypeFile :: ProofType -> String
proofTypeFile pt = case pt of
  Plain               -> "plain"
  SimpleInduction v   -> "simpleind" ++ v
  ApproxLemma         -> "approx"
  FixpointInduction f -> "fix" ++ f

proofTypes :: [ProofType]
proofTypes = [Plain,SimpleInduction "",ApproxLemma,FixpointInduction ""]

liberalEq :: ProofType -> ProofType -> Bool
liberalEq Plain Plain                             = True
liberalEq SimpleInduction{} SimpleInduction{}     = True
liberalEq ApproxLemma ApproxLemma                 = True
liberalEq FixpointInduction{} FixpointInduction{} = True
liberalEq _ _                                     = False

liberalShow :: ProofType -> String
liberalShow Plain               = "plain"
liberalShow SimpleInduction{}   = "simple induction"
liberalShow ApproxLemma         = "approximation lemma"
liberalShow FixpointInduction{} = "fixed point induction"

data Principle k = Principle { principleName  :: Name
                             , principleType  :: ProofType
                             , principleDecor :: k
                             , principleCode  :: String
                             , principleParts :: [Part k]
                             }
  deriving (Eq,Ord,Show,Functor)

type ProofDecl = Principle [T.Decl]

data Part k = Part { partName  :: Name
                   , partDecor :: k
                   , partFail  :: Failure
                   }
  deriving (Eq,Ord,Show,Functor)

type ProofPart = Part [T.Decl]

proofDecl :: Name -> ProofType -> [T.Decl] -> String -> [ProofPart] -> ProofDecl
proofDecl = Principle

proofPart :: Name -> [T.Decl] -> ProofPart
proofPart n d = Part n d Fail

extendProofDecls :: [T.Decl] -> ProofDecl -> ProofDecl
extendProofDecls ts pd = pd { principleDecor = principleDecor pd ++ ts }

extendProofPart :: [T.Decl] -> ProofPart -> ProofPart
extendProofPart ts pp = pp { partDecor = partDecor pp ++ ts }

extendPrinciple :: Part k -> Principle k -> Principle k
extendPrinciple pt pd = pd { principleParts = principleParts pd ++ [pt] }