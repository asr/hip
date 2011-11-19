module Autospec.ToFOL.ProofDatatypes where

import qualified Language.TPTP as T
import Autospec.ToFOL.Core

proofDatatypes :: [Name]
proofDatatypes = ["Prop"]

proveFunctions :: [Name]
proveFunctions = ["prove","proveBool","given","givenBool","=:="]

provable :: Expr -> Bool
provable (App f es) = f `elem` proveFunctions || any provable es
provable _          = False

data ProofDecl = ProofDecl Name [ProofType]
  deriving (Eq,Ord,Show)

data ProofType = Plain [T.Decl]
               | NegInduction [Name] [T.Decl]
               | Induction Bool [Name] [IndPart]
               | ApproxLemma [T.Decl]
  deriving (Eq,Ord,Show)

data IndPart = IndPart { indVarCon :: [Name]
                       , indDecls  :: [T.Decl]
                       }
  deriving (Eq,Ord,Show)