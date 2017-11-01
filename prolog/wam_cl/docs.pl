/*******************************************************************
 *
 * A Common Lisp compiler/interpretor, written in Prolog
 *
 * (xxxxx.pl)
 *
 *
 * Douglas'' Notes:
 *
 * (c) Douglas Miles, 2017
 *
 * The program is a *HUGE* common-lisp compiler/interpreter. It is written for YAP/SWI-Prolog (YAP 4x faster).
 *
 *******************************************************************/
:- module(docs, []).

:- set_module(class(library)).

:- include('header.pro').

maybe_get_docs(Type,Name,[String|FunctionBody],FunctionBody):- string(String),!,
  assert(lisp_documentation(Type,Name,String,FunctionBody)).
maybe_get_docs(_Type,_Name,FunctionBody,FunctionBody).

:- fixup_exports.

