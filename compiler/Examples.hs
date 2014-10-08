{-# OPTIONS_GHC
    -fno-warn-missing-signatures
    -fno-warn-orphans
    -fno-warn-unused-imports #-}

module Examples where

import qualified Src
import Core
import Simplify
import PartialEvaluator
import Inliner

import PrettyUtils

import Unsafe.Coerce

import qualified Language.Java.Syntax as J (Op(..))

instance Show (Expr t e) where
  show e = show $ pprExpr basePrec (0,0) (unsafeCoerce e)

instance Show (Type t) where
  show e = show $ pprType basePrec 0 (unsafeCoerce e)

-- let tailFact : Int -> Int -> Int
--   = \(acc : Int). \(n : Int). if n == 0 then acc else tailFact (acc * n) (n - 1)
-- in
-- tailFact 1 10
tailFact :: Expr t e
tailFact
  = Fix (\tail_fact acc ->
      Lam javaInt (\n ->
        If (Var n `eq` zero)
           (Var acc)
           (Var tail_fact `App` (Var acc `mult` Var n) `App` (Var n `sub` one))))
    javaInt (javaInt `Fun` javaInt)


testTail :: Expr t e
testTail = Fix (\f n -> If (Var n `eq` zero)
                           one
                           (Var f `App` (Var n `sub` one)))
               javaInt
               (javaInt `Fun` javaInt)

fact :: Expr t (Expr t e)
fact = Fix (\f n -> If (Var n `eq` zero)
                       one
                       (Var n `mult` (Var f `App` (Var n `sub` one))))
           javaInt
           (javaInt `Fun` javaInt)

tailFactLike :: Expr t e
tailFactLike
  = Fix (\tail_fact acc ->
      Lam javaInt (\n ->
        If (Var n `eq` zero)
           (Var acc)
           (Var tail_fact `App` (Var acc `mult` one) `App` one)))
    javaInt (javaInt `Fun` javaInt)

-- let rec
--   even : Int -> Int = \(n : Int). if n == 0 then True  else odd  (n - 1)
--   odd  : Int -> Int = \(n : Int). if n == 0 then False else even (n - 1)
-- in
-- even 42

evenOdd :: Expr t e
evenOdd
  = LetRec
      [(Fun javaInt javaBool), (Fun javaInt javaBool)]
      (\ids ->
         [ Lam javaInt (\n -> If (Var n `eq` zero) true  (App (Var (ids !! 1)) (Var n `sub` one)))
         , Lam javaInt (\n -> If (Var n `eq` zero) false (App (Var (ids !! 0)) (Var n `sub` one)))])
      (\ids ->
         App (Var (ids !! 1)) magicNumber)


-- Int -> (Int -> Bool, Int -> Bool)
evenOddEncodedTy :: Type t
evenOddEncodedTy = javaInt `Fun` Product [javaInt `Fun` javaBool, javaInt `Fun` javaBool]

-----------------------
-- peval tests
-----------------------
identity :: Expr t e
identity = Lam javaInt (\x -> Var x)
id_1 = App identity one

id_twice = Lam javaInt (\x -> App identity (Var x))
app_id_twice_1 = App id_twice one

--id_4times = Lam javaInt (\x -> App id_twice

app_lam_if = App (Lam javaInt (\x -> If ((Var x) `eq` one)
                                 ((Var x) `sub` one)
                                 (zero `sub` one)))
             (zero `sub` one)
app_lam_app = App (Lam javaInt (\x -> App (Lam javaInt (\y -> (Var x) `sub` (Var y))) zero))
              one

fix = Fix (\f n -> If (((one `sub` zero) `eq` zero))
                   one
                   (Var n `mult` (Var f `App` (Var n `sub` one))))
      javaInt
      (javaInt `Fun` javaInt)
app_fix = App fix (Lit (Src.Integer 10))

-- test App e1 e2, where e1 can be partially evaluated to a Lam
minus = Lam javaInt (\x -> Lam javaInt (\y -> Var x `sub` Var y))
minus_1 = App minus one
minus_1_0 = App minus_1 zero

if_lam = If (one `eq` one) (App minus one) (App minus zero)
app_if_lam = App if_lam one

-- complex test
complex_eq_zero = If (((App identity minus_1_0) `sub` one) `eq` zero)
                  zero
                  one

javaInt      = JClass "java.lang.Integer"
javaBool     = JClass "java.lang.Boolean"
zero         = Lit (Src.Integer 0)
one          = Lit (Src.Integer 1)
magicNumber  = Lit (Src.Integer 42)
true         = Lit (Src.Boolean True)
false        = Lit (Src.Boolean False)
x `eq` y     = PrimOp x (Src.Compare J.Equal) y
x `sub` y    = PrimOp x (Src.Arith J.Sub) y
x `mult` y   = PrimOp x (Src.Arith J.Mult) y
