(* Yoann Padioleau
 *
 * Copyright (C) 2013 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* The AST related types *)
(*****************************************************************************)

(* ------------------------------------------------------------------------- *)
(* Token/info *)
(* ------------------------------------------------------------------------- *)
type info = Parse_info.info

type enum = 

(* ------------------------------------------------------------------------- *)
(* Names  *)
(* ------------------------------------------------------------------------- *)

(* ------------------------------------------------------------------------- *)
(* Comments *)
(* ------------------------------------------------------------------------- *)

 | FullComment
 | TextComment
 | ParagraphComment
 | InlineCommandComment
 | VerbatimLineComment
 | BlockCommandComment

(* ------------------------------------------------------------------------- *)
(* Attributes *)
(* ------------------------------------------------------------------------- *)

 | VisibilityAttr
 | DeprecatedAttr
 | MaxFieldAlignmentAttr
 | AlwaysInlineAttr
 | NoDebugAttr
 | ConstAttr
 | NoThrowAttr
 | NonNullAttr
 | AsmLabelAttr
 | PackedAttr
 | FormatAttr
 | AlignedAttr
 | WarnUnusedResultAttr
 | MayAliasAttr
 | PureAttr
 | MallocAttr
 | ReturnsTwiceAttr
 | UnusedAttr
 | FormatArgAttr
 | UnavailableAttr
 | TransparentUnionAttr
 | BlocksAttr

(* ------------------------------------------------------------------------- *)
(* Misc *)
(* ------------------------------------------------------------------------- *)

 | Misc__Null__
 | Misc__Capture__
 | Misc__Cleanup__Block

(* ------------------------------------------------------------------------- *)
(* Expressions *)
(* ------------------------------------------------------------------------- *)

 | IntegerLiteral
 | StringLiteral
 | FloatingLiteral
 | CharacterLiteral

 | UnaryOperator
 | BinaryOperator
 | ConditionalOperator
 | CompoundAssignOperator

 | DeclRefExpr
 | ImplicitCastExpr
 | CStyleCastExpr
 | CallExpr
 | MemberExpr
 | ArraySubscriptExpr
 | InitListExpr
 | CompoundLiteralExpr
 | ShuffleVectorExpr
 | UnaryExprOrTypeTraitExpr
 | BlockExpr
 | ParenExpr

 | ExprWithCleanups

(* ------------------------------------------------------------------------- *)
(* Statements *)
(* ------------------------------------------------------------------------- *)
 | CompoundStmt
 | NullStmt
 | DeclStmt
 | IfStmt
 | ForStmt
 | WhileStmt
 | DoStmt
 | BreakStmt
 | ContinueStmt
 | SwitchStmt
 | CaseStmt
 | DefaultStmt
 | ReturnStmt
 | GotoStmt
 | LabelStmt
 | GCCAsmStmt

(* ------------------------------------------------------------------------- *)
(* Decl *)
(* ------------------------------------------------------------------------- *)

 | FunctionDecl
 | EnumDecl
 | EnumConstantDecl
 | RecordDecl
 | FieldDecl
 | TypedefDecl
 | VarDecl
 | BlockDecl
 | ParmVarDecl

 | TranslationUnitDecl

(*****************************************************************************)
(* Intermediate representations *)
(*****************************************************************************)

type sexp = 
  | Paren of enum * sexp list
  | Angle of sexp list
  | Anchor of sexp list
  | Bracket of sexp list
  (* everything except the TOxxx and TCxxx normally *)
  | T of Parser_clang.token 
(* ------------------------------------------------------------------------- *)
(* Toplevel phrases *)
(* ------------------------------------------------------------------------- *)

type program = sexp
