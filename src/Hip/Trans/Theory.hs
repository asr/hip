module Hip.Trans.Theory where

import Hip.Trans.Core
import Hip.Trans.ProofDatatypes hiding (propName)
import Hip.Trans.Pretty
import Hip.Trans.TyEnv
import Hip.Trans.NecessaryDefinitions
import Hip.Util

import Halt.FOL.Abstract

import qualified Test.QuickSpec.Term as QST

import qualified Language.TPTP as T

import Control.Arrow ((&&&),first)

import Data.Set (Set)
import qualified Data.Set as S
import Data.Map (Map)
import qualified Data.Map as M

import Data.Graph
import Data.Tree
import Data.Maybe


data Theory = Theory { thyDataAxioms :: [AxClause]
                     , thyDefAxioms  :: [VarClause]
                     }


data Prop = Prop { proplhs  :: Expr
                 , proprhs  :: Expr
                 , propVars :: [Name]
                 , propName :: Name
                 , propType :: Type
                 , propRepr :: String
                 , propQSTerms :: (QST.Term QST.Symbol,QST.Term QST.Symbol)
                 }
  deriving (Eq,Ord,Show)

inconsistentProp :: Prop
inconsistentProp = Prop { proplhs  = Con "True" []
                        , proprhs  = Con "False" []
                        , propVars = []
                        , propName = color Red "inconsistencyCheck"
                        , propType = TyCon "Prop" [TyCon "Bool" []]
                        , propRepr = "inconsistecy check: this should never be provable"
                        }

theoryFunDecls :: Theory -> [Decl]
theoryFunDecls = map funcDefinition . thyFuns

theoryRecFuns :: Theory -> Set Name
theoryRecFuns = S.fromList . map funcName . filter funcRecursive . thyFuns

theoryFunTPTP :: Theory -> [T.Decl]
theoryFunTPTP = concatMap funcTPTP . thyFuns

theoryUsedPtrs :: Theory -> [(Name,Int)]
theoryUsedPtrs = nubSorted . concatMap funcPtrs . thyFuns

theoryFiniteType :: Theory -> Type -> Bool
theoryFiniteType = undefined

theoryDataTypes :: Theory -> [Type]
theoryDataTypes = map (\d -> TyCon (declName d) (map TyVar (declArgs d))) . thyDatas

theoryTyEnv :: Theory -> TyEnv
theoryTyEnv = map (declName &&& conTypes) . thyDatas