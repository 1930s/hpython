{-# language OverloadedStrings, OverloadedLists #-}
module LexerParser (lexerParserTests) where

import Data.Functor.Alt ((<!>))
import qualified Data.Functor.Alt as Alt (many)
import Hedgehog

import Language.Python.Internal.Lexer
import Language.Python.Internal.Parse
import Language.Python.Internal.Render
import Language.Python.Internal.Syntax.Whitespace

import Helpers (doToPython, doParse, doNested, doTokenize, doIndentation)

lexerParserTests :: Group
lexerParserTests =
  Group "Lexer/Parser tests"
  [ ("Test parse 1", test_parse_1)
  , ("Test parse 2", test_parse_2)
  , ("Test full trip 1", test_fulltrip_1)
  , ("Test full trip 2", test_fulltrip_2)
  , ("Test full trip 3", test_fulltrip_3)
  , ("Test full trip 4", test_fulltrip_4)
  , ("Test full trip 5", test_fulltrip_5)
  , ("Test full trip 6", test_fulltrip_6)
  , ("Test full trip 7", test_fulltrip_7)
  , ("Test full trip 8", test_fulltrip_8)
  , ("Test full trip 9", test_fulltrip_9)
  , ("Test full trip 10", test_fulltrip_10)
  , ("Test full trip 11", test_fulltrip_11)
  , ("Test full trip 12", test_fulltrip_12)
  ]

test_fulltrip_1 :: Property
test_fulltrip_1 =
  withTests 1 . property $ do
    let str = "def a(x, y=2, *z, **w):\n   return 2 + 3"
    a <- doToPython statement str
    renderLines (renderStatement a) === str

test_fulltrip_2 :: Property
test_fulltrip_2 =
  withTests 1 . property $ do
    let str = "(   1\n       *\n  3\n    )"
    a <- doToPython (expr space) str
    renderExpr a === str

test_fulltrip_3 :: Property
test_fulltrip_3 =
  withTests 1 . property $ do
    let str = "pass;"
    a <- doToPython statement str
    renderLines (renderStatement a) === str

test_fulltrip_4 :: Property
test_fulltrip_4 =
  withTests 1 . property $ do
    let str = "def a():\n pass\n #\n pass\n"

    tks <- doTokenize str
    annotateShow tks

    let lls = logicalLines tks
    length lls === 4
    annotateShow lls

    ils <- doIndentation lls
    annotateShow ils

    nst <- doNested ils
    annotateShow nst

    a <- doToPython statement str
    renderLines (renderStatement a) === str

test_fulltrip_5 :: Property
test_fulltrip_5 =
  withTests 1 . property $ do
    let str = "if False:\n pass\n pass\nelse:\n pass\n pass\n"

    tks <- doTokenize str
    annotateShow tks

    let lls = logicalLines tks
    length lls === 6
    annotateShow lls

    ils <- doIndentation lls
    annotateShow ils

    nst <- doNested ils
    annotateShow nst

    a <- doToPython statement str
    renderLines (renderStatement a) === str

test_fulltrip_6 :: Property
test_fulltrip_6 =
  withTests 1 . property $ do
    let str = "# blah\ndef boo():\n    pass\n       #bing\n    #   bop\n"

    tks <- doTokenize str
    annotateShow tks

    let lls = logicalLines tks
    length lls === 5
    annotateShow lls

    ils <- doIndentation lls
    annotateShow ils

    nst <- doNested ils
    annotateShow nst

    a <- doToPython module_ str
    renderModule a === str

test_fulltrip_7 :: Property
test_fulltrip_7 =
  withTests 1 . property $ do
    let str = "if False:\n pass\nelse \\\n      \\\r\n:\n pass\n"

    tks <- doTokenize str
    annotateShow tks

    let lls = logicalLines tks
    annotateShow lls

    ils <- doIndentation lls
    annotateShow ils

    nst <- doNested ils
    annotateShow nst

    a <- doToPython module_ str
    renderModule a === str

test_fulltrip_8 :: Property
test_fulltrip_8 =
  withTests 1 . property $ do
    let str = "def a():\n \n pass\n pass\n"

    tks <- doTokenize str
    annotateShow tks

    let lls = logicalLines tks
    annotateShow lls

    ils <- doIndentation lls
    annotateShow ils

    nst <- doNested ils
    annotateShow nst

    a <- doToPython module_ str
    renderModule a === str

test_fulltrip_9 :: Property
test_fulltrip_9 =
  withTests 1 . property $ do
    let
      str =
        "try:\n pass\nexcept False:\n pass\nelse:\n pass\nfinally:\n pass\n def a():\n  pass\n pass\n"

    tks <- doTokenize str
    annotateShow tks

    let lls = logicalLines tks
    annotateShow lls

    ils <- doIndentation lls
    annotateShow ils

    nst <- doNested ils
    annotateShow nst

    a <- doParse module_ nst
    annotateShow a

    renderModule a === str

test_fulltrip_10 :: Property
test_fulltrip_10 =
  withTests 1 . property $ do
    let
      str =
        unlines
        [ "from blah import  boo"
        , "import baz   as wop"
        , ""
        , "def thing():"
        , "    pass"
        , ""
        , "def    hello():"
        , "    what; up;"
        , ""
        , "def boo(a, *b, c=1, **d):"
        , "    pass"
        ]

    tks <- doTokenize str
    annotateShow $! tks

    let lls = logicalLines tks
    annotateShow $! lls

    ils <- doIndentation lls
    annotateShow $! ils

    nst <- doNested ils
    annotateShow $! nst

    a <- doParse module_ nst
    annotateShow $! a

    renderModule a === str

test_fulltrip_11 :: Property
test_fulltrip_11 =
  withTests 1 . property $ do
    let
      str =
        unlines
        [ "if False:"
        , " pass"
        , " pass"
        , "else:"
        , " \tpass"
        , " \tpass"
        ]

    tks <- doTokenize str
    annotateShow $! tks

    let lls = logicalLines tks
    annotateShow $! lls

    ils <- doIndentation lls
    annotateShow $! ils

    nst <- doNested ils
    annotateShow $! nst

    a <- doParse module_ nst
    annotateShow $! a

    renderModule a === str

test_fulltrip_12 :: Property
test_fulltrip_12 =
  withTests 1 . property $ do
    let
      str =
        unlines
        [ "try:"
        , " \tpass"
        , " \tdef a():"
        , " \t pass"
        , " \tpass"
        , "finally:"
        , " pass"
        ]

    tks <- doTokenize str
    annotateShow $! tks

    let lls = logicalLines tks
    annotateShow $! lls

    ils <- doIndentation lls
    annotateShow $! ils

    nst <- doNested ils
    annotateShow $! nst

    a <- doParse module_ nst
    annotateShow $! a

    renderModule a === str

parseTab :: Parser ann Whitespace
parseTab = do
  curTk <- currentToken
  case curTk of
    TkTab{} -> pure Tab
    _ -> parseError $ ExpectedToken (TkTab ()) curTk

parseSpace :: Parser ann Whitespace
parseSpace = do
  curTk <- currentToken
  case curTk of
    TkSpace{} -> pure Space
    _ -> parseError $ ExpectedToken (TkSpace ()) curTk

test_parse_1 :: Property
test_parse_1 =
  withTests 1 . property $ do
    let
      line =
        [ IndentedLine
            LogicalLine
            { llAnn = ()
            , llSpaces = []
            , llLine = [ TkTab () ]
            , llEnd = Nothing
            }
        ]

    nested <- doNested line

    res <- doParse (parseSpace <!> parseTab) nested
    case res of
      Tab -> success
      _ -> annotateShow res *> failure

test_parse_2 :: Property
test_parse_2 =
  withTests 1 . property $ do
    let
      line =
        [ IndentedLine
            LogicalLine
            { llAnn = ()
            , llSpaces = []
            , llLine = [ TkSpace (), TkSpace (), TkSpace (), TkSpace () ]
            , llEnd = Nothing
            }
        ]

    nested <- doNested line

    () <$ doParse (Alt.many space) nested