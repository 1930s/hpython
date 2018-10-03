{-# language OverloadedStrings #-}
module Syntax (syntaxTests) where

import Hedgehog
import Data.Validation (Validation(..))

import Language.Python.Internal.Syntax.CommaSep
import Language.Python.Internal.Syntax.Expr
import Language.Python.Internal.Syntax.Whitespace

import Helpers (syntaxValidateExpr)

syntaxTests :: Group
syntaxTests =
  Group "Syntax tests"
  [ ("Syntax test 1", withTests 1 test_1)
  ]

shouldBeFailure :: Validation e a -> PropertyT IO ()
shouldBeFailure res =
  case res of
    Success{} -> failure
    Failure{} -> success

test_1 :: Property
test_1 =
  property $ do
    let
      e =
        -- lambda *: None
        Lambda ()
          [Space]
          (CommaSepMany (StarParam () [] Nothing Nothing) [] CommaSepNone)
          [Space]
          (None () [])
    res <- syntaxValidateExpr e
    shouldBeFailure res