/*******************************************************************
 *
 * A Common Lisp compiler/interpretor, written in Prolog
 *
 * (symbol_places.pl)
 *
 *
 * Douglas'' Notes:
 *
 * (c) Douglas Miles, 2017
 *
 * The program is a *HUGE* common-lisp compiler/interpreter. It is written for YAP/SWI-Prolog (YAP 4x faster).
 *
 *******************************************************************/
:- module(block_tagbody,[]).

:- set_module(class(library)).

:- include('header').


%:- dynamic(compile_body_h/5).
%:- multifile(compile_body_h/5).
:- discontiguous(compile_body_h/5).



/*
[tagbody, 
   Named0 = (c0,o0,d0,e0),
   Named1 = code1,
   named2 = (co2,de2) ):-

     


 (tagbody
   (setq val 2)
   (go lp)
   (incf val 3)
   lp (incf val 4)) 
=> 6
     */

% :- thread_local(t_l:btb/2).
%:- discontiguous(t_l:btb/2).

/*

Interpretor...


call_block_interp(Name,Value):- 
  btba(Name,InstrS,Addrs),
  call_instructions_pc(0,InstrS,Addrs,Value).

btba(Name,InstrS,Addrs):-
   t_l:btb(Name,InstrS),
   always(get_addrs(0,InstrS,Addrs)).

% TODO - dont bother recording adresses until after the first 'GO'/1
get_addrs(_,[],[]):-!.
get_addrs(N,[TagInstr|InstrS],[addr2(Label,N)|Addrs]):- is_label(TagInstr,Label),!,
  N1 is N + 1,
  get_addrs(N1,InstrS,Addrs).
get_addrs(N,[_|InstrS],Addrs):- 
  N1 is N + 1,
  get_addrs(N1,InstrS,Addrs).
  

call_instructions_pc(PC,InstrS,Addrs,Value):- 
   nth0(PC,InstrS,I)->call_i_pc(I,PC,InstrS,Addrs,Value);true.

% #:LABEL allows rearrangments and address changes
call_i_pc(TagInstr,PC,InstrS,Addrs,Value):- is_label(TagInstr,Label),!,
   PC2 is PC + 1,
   call_instructions_pc(PC2,InstrS,[addr2(Label,PC)|Addrs],Value).
% #:GO 
call_i_pc([go,Label],_PC,InstrS,Addrs,Value):-!,
   always(member(addr2(Label,_,Where),Addrs)),
   call_instructions_pc(Where,InstrS,Addrs,Value).
% #:RETURN
call_i_pc('return-from'(_,Value),_PC,_Instr,_Addrs,Value):-!.
% #normal call
call_i_pc(I,PC,InstrS,Addrs,Value):-!,
   call(I),
   PC2 is PC + 1,
   call_instructions_pc(PC2,InstrS,Addrs,Value).

*/

/* testing */



/*

Compiler...

TODO: This might be rewritten to not use a numbers as addresses
Instead simply grab the List''s reference at some numerical points

 (let (val)
    (tagbody
[      (setq val 1)
*      (go point-a)]
      (incf val 16)
[     point-c
      (incf val 04)
*      (go point-b)]
      (incf val 32)
[    point-a
      (incf val 02)
*      (go point-c)
      (incf val 64)
     point-b
      (incf val 08))
    val)
=>  15


    Tagbody = 
     (setq(val,1)
      call_then_return(Point_A),
      incf(val,16),
      Point_C =
      (incf(val,04),
       call(Point_B),
       incf(val,32)),
     Point_A =
      (incf(val,02)
      call_then_return(Point_C),
      incf(val,64))
     Point_B =
      incf(val,08),
      nb_current(var,Value),
      'return-from'([],Value,Result)),
    catch(TagBody,'return-from'(_,Value),true).


*/

tst:is_local_test(tagbody_let3,
 [let, [b],
     [tagbody,
         setq(b,2),go(tag2),
         setq(a,1), % never seen
         (tag1),setq(b,3),go(tag3),
         (tag2),setq(a,4),go(tag1),
         (tag3),print('1+'(plus(a,b)))
     ],
  b],3).


tst:is_local_test(tagbody7_prints_8,
  [tagbody,
      setq(b,2),go(tag2),
      setq(a,1), % never seen
      (tag1),setq(b,3),go(tag3),
      (tag2),setq(a,4),go(tag1),
      (tag3),print('1+'(plus(a,b)))
   ],7).



tst:is_local_test_HIDE(tagbody6,[tagbody,
   setq(b,2),[go,tag2],setq(a,1),
   (tag1),setq(a,4),prolog_call([a,b],plus(a,b,C)),prolog_call(writeln(C)),
   (tag2),setq(a,4),[go,tag1]],6).

compile_tagbody_forms(Ctx,Env,Result,[enter(_)|InstrS],BInstrS):- !,compile_tagbody_forms(Ctx,Env,Result,InstrS,BInstrS).
compile_tagbody_forms(Ctx,Env,Result,InstrS,BInstrS):-
   maplist(label_atoms,InstrS,TInstrS),
   trim_tagbody(TInstrS,CInstrS),
   compile_forms(Ctx,Env,Result,CInstrS,BInstrS).

trim_tagbody(InstrS,TInstrS):- append(Left,[R|_],InstrS),is_reflow(R,_),!,append(Left,[R],TInstrS).
trim_tagbody(InstrS,InstrS).

%label_atoms(Instr,[label,Tag]):- is_label(Instr,Tag),!.
label_atoms(Tag,[label,Tag]):-atomic(Tag),!.
label_atoms(Instr,Instr).

shared_lisp_compiler:plugin_expand_progbody(Ctx,Env,Result,InstrS,_PreviousResult,Code):- 
  compile_body_h(Ctx,Env,Result,InstrS,Code),!.


compile_body_h(_Ctx,_Env,Result, nop(X),  nop(X)):- !, debug_var("_NopResult",Result).
compile_body_h(_Ctx,_Env,Result,[label, Tag], push_label(Tag) ):- debug_var("_LABELRES",Result).
compile_body_h(_Ctx,_Env,Result,exit( Tag), push_label(exit( Tag)) ):- debug_var("_GORES",Result).
compile_body_h(_Ctx,_Env,Result,enter( Tag), push_label(enter( Tag)) ):- debug_var("_GORES",Result).
compile_body_h(Ctx,Env,Result,[tagbody| InstrS], Code):- debug_var("_TBResult",Result),!,
  compile_as_tagbody(Ctx,Env,Result,InstrS,Code).

% goto(Label,Value,Env)
compile_body_h(_Ctx,Env,Result,[go, Tag], goto(Tag,[],Env) ):- debug_var("_GORES",Result),debug_var("GoEnv",Env).
compile_body_h(Ctx,Env,GoResult,['return-from',Tag,ValueForm], (ValueBody, goto(exit(Tag),ValueResult,Env)) ):- 
  compile_body(Ctx,Env,ValueResult,ValueForm, ValueBody),
  debug_var("_GORES",GoResult),
  debug_var("RetVal",ValueResult).

compile_body_h(Ctx,Env,Result,['return',Value],Body):-!,compile_body_h(Ctx,Env,Result,['return-from',[],Value],Body).
compile_body_h(Ctx,Env,Result,return(Value), Body ):- !,compile_body_h(Ctx,Env,Result,[return, Value],Body).
compile_body_h(Ctx,Env,Result,go(Tag), Body ):- !,compile_body_h(Ctx,Env,Result,[go, Tag],Body).

compile_body_h(_Ctx,_Env,_Result,call(Body), call(Body) ):-!.


compile_body_h(Ctx,Env,ResultOut,prolog_call(Body), call(BodyResolved) ):-
   compile_prolog_call(Ctx,Env,[],ResultOut,Body,BodyResolved),!.
compile_body_h(Ctx,Env,ResultOut,prolog_call(Resolve,Body), call(BodyResolved) ):-
   compile_prolog_call(Ctx,Env,Resolve,ResultOut,Body,BodyResolved),!.


/*
compile_prolog_call(_Ctx,Env,ResultOut,[],Body,BodyOut):-subst(Body,'$out',ResultOut,BodyMid),subst(BodyMid,'$env',Env,BodyOut).
compile_prolog_call(Ctx,Env,ResultOut,[R|Resolve],Body,(Code,BodyResolved)):-
  subst(Body,R,Result,BodyMid),
  must_compile_body(Ctx,Env,Result,R,Code),
  compile_prolog_call(Ctx,Env,ResultOut,Resolve,BodyMid,BodyResolved).
*/


/*
TODO fix prolog_call

tst:is_local_test(block2,[block,block2,[tagbody,setq(b,2),[go,tag2],setq(a,1),(tag1),
                     prolog_call([a,b],plus(a,b,C)),prolog_call(writeln(C)),
                     'return-from'(block2,c),(tag2),setq(a,4),[go,tag1]]],6).
*/
compile_body_h(Ctx,Env,Result,[block,Tag|InstrS], Code):- 
  compile_block(Ctx,Env,Result,Tag,InstrS,Code),!.

compile_block(Ctx,Env,Result,Tag,InstrS,Code):-
 append([[go,enter(Tag)],enter(Tag)|InstrS],[[go,exit(Tag)],exit(Tag)],WInstrS),
 compile_as_tagbody(Ctx,Env,Result,WInstrS,Code).

tst:is_local_test(do(0.0),
"(do ((temp-one 1 (1+ temp-one))
       (temp-two 0 (1- temp-two)))
      ((> (- temp-one temp-two) 5) temp-one))", 4).

tst:is_local_test(do(0.1),
"(do ((temp-one 1 (1+ temp-one))
       (temp-two 0 (1+ temp-one)))     
      ((= 3 temp-two) temp-one))",  3).

compile_body_h(Ctx,Env,Result,[do,LoopVars,[EndTest|ResultForms]|TagBody], Code):- 
   loop_vars_to_let_n_step(LoopVars,LetVars,[],PSetQStepCode),
   gensym(dosym,Tag),
   must_compile_body(Ctx,Env,Result,
    [block,[],       
      [let,LetVars,
          [tagbody,
            [label,Tag],
            [if,
              EndTest,
               ['return-from',[],[progn|ResultForms]],
               [progn,[progn|TagBody],[psetq|PSetQStepCode]]
            ],
            go(Tag)]
       ]
     ],  Code).



 
/* loop_vars_to_let_n_step([],[],InOut,InOut).
loop_vars_to_let_n_step([Decl|LoopVars],[Norm|LetVars],In,Out):-
  always(loop_1var_n_step(Decl,Norm,More)),
  append(In,More,Mid),
  loop_vars_to_let_n_step(LoopVars,LetVars,Mid,Out).


% loop_1var_n_step([bind, Variable, Form],[bind, Variable, Form],[]).
loop_1var_n_step([Variable, Form, Step],[bind, Variable, Form],[Variable,Step]).
loop_1var_n_step([Variable, Form],[bind, Variable, Form],[]).
loop_1var_n_step(Variable,[bind, Variable, []],[]).
*/


tst:is_local_test(tagbody1,[tagbody,setq(b,2),[go,tag1],setq(a,1),(tag1),setq(a,4),print(plus(a,b))],[]).
compile_as_tagbody(Ctx,Env,Result,InstrS,Code):-
   always(get_go_points(InstrS,Gos)),
   always(get_tags(Env,InstrS,Gos,Addrs)), 
   check_missing_gos(Gos),   
   compile_addrs(Ctx,Env,Result,Addrs),
   compile_tagbody_forms(Ctx,Env,Result,InstrS,CInstrS),
   copy_term(Addrs,Addrs2),
   Code = call_addr_block(Env,CInstrS,Addrs2,Result).

/*
call_addr_block(EnvIn,Start,Addrs,Result):-  fail,
  catch(Start,
      goto(Label,Result,EnvCatch),
           (always(member(addr(Label,_,NewEnv,NewCode),Addrs)),
           copy_term(NewEnv:NewCode,NewEnvCopy:NewCodeCopy),
           NewEnvCopy = EnvCatch,
           call_addr_block(NewEnvCopy,NewCodeCopy,Addrs,Result))).
*/
   /*
call_addr_block(EnvCatch,Start,Addrs,Result):-
  catch(Start,
      goto(Label,ResultE,EnvCatchE),
           ((member(addr(Label,_,NewEnv,NewCode),Addrs)->!;throw(goto(Label,ResultE,EnvCatchE))),
           copy_term(NewEnv:NewCode,NewEnvCopy:NewCodeCopy),
           NewEnvCopy = EnvCatchE,
           ignore(ResultE = Result),
           call_addr_block(EnvCatch,NewCodeCopy,Addrs,Result))).
*/
call_addr_block(EnvCatch,Start,Addrs,Result):-
  catch(Start,
      goto(Label,ResultE,EnvCatch),
           ((member(addr(Label,_,NewEnv,NewCode),Addrs)->!;throw(goto(Label,ResultE,EnvCatch))),
           copy_term(NewEnv:NewCode,NewEnvCopy:NewCodeCopy),
           NewEnvCopy = EnvCatch,
           ignore(ResultE = Result),
           call_addr_block(EnvCatch,NewCodeCopy,Addrs,Result))).


goto(Label,Value,Env):- notrace(throw(goto(Label,Value,Env))).
push_label(_).
%'return-from'(Label,Result):-throw(goto(Result,exit(Label),Env)).
%return(G):- 'return-from'([],G).
%call_then_return(G):- G,goto(exit(_),[],Env).

/*
call_addr_block(Env,[],'return-from'([]),_Result):-!.
% #:ATOM or #:LABEL allows rearrangments and address changes
call_addr_block(Env,[(TagInstr)|InstrS],Addrs,Result):- is_label(TagInstr,Label),!,
   call_addr_block(Env,InstrS,[addr(Label,'$late',InstrS)|Addrs],Result).
% #:GO 
call_addr_block(Env,[goto(Result,Label)|_],Addrs,Result):-!,
   always(member(addr(Label,_,Where),Addrs)),
   copy_term(Where,Copy),
   call_addr_block(Env,Copy,Addrs,Result).
% #normal call
call_addr_block(Env,[I|InstrS],Addrs,Result):- call(I),
  call_addr_block(Env,InstrS,Addrs,Result).
*/

is_reflow([OP|ARGS],Label):- is_reflow(OP,ARGS,Label).
is_reflow(OPARGS,Label):- OPARGS=..[OP|ARGS],is_reflow(OP,ARGS,Label).
is_reflow('go',[Label|_],Label).
is_reflow('cl_go',[Label|_],Label).
is_reflow('goto',[Label|_],Label).
is_reflow('tagbody_go',[Label|_],Label).
is_reflow('gosub',[Label|_],Label).
is_reflow('return',_,[]).
is_reflow(OP,[Label|_],Label):- same_symbol(OP,'return-from').
is_reflow('throw',[Label|_],Label).


is_label(Atom,Atom):- atomic(Atom),!,Atom\==[].
is_label([OP|ARGS],Label):- is_label(OP,ARGS,Label).
is_label(OPARGS,Label):- OPARGS=..[OP|ARGS],is_label(OP,ARGS,Label).
is_label('enter',[Label|_],Label).
is_label('exit',[Label|_],Label).
is_label('label',[Label|_],Label).

is_branched([Op|_]):- fail,member(Op,[if,or,and,progn]).



get_go_points([FlowInst|InstrS],[addr(Label,'$used','$missing','$missing')|Addrs]):- is_reflow(FlowInst,Label),!,
  get_go_points(InstrS,Addrs).
get_go_points([],[]).
get_go_points([I|InstrS],Addrs):-% #branching call
  is_branched(I),get_go_points(I,IAddrs),
  get_go_points(InstrS,NAddrs),
  append(IAddrs,NAddrs,Addrs).
get_go_points([_|InstrS],Addrs):-
  get_go_points(InstrS,Addrs).

get_tags(Env,[Label|InstrS],Gos,[GAddrs|Addrs]):- atomic(Label),
  member(GAddrs,Gos),GAddrs=addr(Label,_Used,_Env_,_Missing), !,
   setarg(3,GAddrs,Env),
   setarg(4,GAddrs,InstrS),
  get_tags(Env,InstrS,Gos,Addrs).
get_tags(Env,[Label|InstrS],Gos,[GAddrs|Addrs]):-
  member(GAddrs,Gos),GAddrs=addr(Label,_Used,_Env_,_Missing),
   setarg(3,GAddrs,Env),
   setarg(4,GAddrs,InstrS),
  get_tags(Env,InstrS,Gos,Addrs).
get_tags(Env,[TagInstr|InstrS],Gos,[GAddrs|Addrs]):- is_label(TagInstr,Label),
   GAddrs = addr(Label,'$unused','$env',InstrS),
    setarg(3,GAddrs,Env),
    setarg(4,GAddrs,InstrS),
  get_tags(Env,InstrS,[GAddrs|Gos],Addrs).
get_tags(_Env,[],_,[]).
get_tags(Env,[I|InstrS],Gos,Addrs):- % #branching call
  is_branched(I),get_tags(Env,I,Gos,IAddrs),
  get_tags(Env,InstrS,Gos,NAddrs),
  append(IAddrs,NAddrs,Addrs).
get_tags(Env,[_|InstrS],Gos,Addrs):-
  get_tags(Env,InstrS,Gos,Addrs).

% @todo
check_missing_gos(_).

% asserta((fifteen(Val_Thru23):-!, []=[[]], LETENV=[[bv(val, [[]|_832])]], 
%   call_addr_block(Env,(symbol_setq(val, 1, _1398), goto(Result,'point-a')), [addr('point-c', '$used',  (push_label('point-c'), sym_arg_val_env(val, Val_In, Val_Thru, LETENV), incf(Val_Thru, 4, Incf_Ret), goto(Result,'point-b'))), addr('point-a', '$used',  (push_label('point-a'), push_label('point-d-unused'), sym_arg_val_env(val, Val_In12, Val_Thru13, LETENV), incf(Val_Thru13, 2, Incf_Ret14), goto(Result,'point-c'))), addr('point-d-unused', '$unused',  (push_label('point-d-unused'), sym_arg_val_env(val, Val_In17, Val_Thru18, LETENV), incf(Val_Thru18, 2, Incf_Ret19), goto(Result,'point-c'))), addr('point-b', '$used', ['point-b', [incf, val, 8]])], _GORES15), sym_arg_val_env(val, Val_In22, Val_Thru23, LETENV)))


compile_addrs(Ctx,Env,Result,[A|Addrs]):-
  compile_addr1(Ctx,Env,Result,A),
  compile_addrs(Ctx,Env,Result,Addrs).
compile_addrs(_Ctx,_Env,_Result,_).

compile_addr1(Ctx,_Env,Result,A):- A= addr(_Tag,_Unused,_E,InstrS),   
   always(compile_tagbody_forms(Ctx,NewEnv,Result,InstrS,Code)),
   setarg(3,A,NewEnv),
   setarg(4,A,Code),!.
compile_addr1(_Ctx,_Env,_Result,_):- !.





tst:is_local_test(block3,
   [block,block3,setq(b,2),[go,tag1],setq(a,1),(tag1),setq(a,4),print(plus(a,b)),'return-from'(block3,plus(a,b))],6).


make_cont(G,Cont):-
  	reset(((   
          shift(mc(G))
	     ->  G
	     ;   true
	     )), mc(G), Cont).

reset_in_cond4(R):-
  make_cont((format(atom(R), 'Hello ~w', [X]);format(atom(R), 'Bye ~w', [X])),Cont),
   X = world,
   call(Cont).

loop_cont:-
   make_cont(writeln([x=X,y=Y]),Cont1),
   make_cont(once(number(Y)->X is Y+1;X=1),CalcX),
   make_cont(once(number(X)->Y is X+1;Y=1),CalcY),
   \+ \+ call(CalcY),
   call(CalcX),
   call(Cont1).


local_test_1(SExpression):- 
  as_sexp(SExpression,Expression),
  dbmsg(lisp_compile(Expression)),
  always(lisp_compile(Result,Expression,Code)),
  dbmsg(Code),
  always(call(Code)),
  dbmsg(result(Result)).

local_test_2(SExpression,Result):- 
  as_sexp(SExpression,Expression),
  dbmsg(lisp_compiled_eval(Expression)),
  always(lisp_compile(Expression,Code)),
  dbmsg(Code),
  nop((always(call(Code)),dbmsg(result(Result)))).

tst:is_local_test(let_simple,
"(defun let_simple ()
  (let (val)
    val))
    ",[]).

tst:is_local_test(let_simple1,
"(defun let_simple1 ()
  (let ((val 1))
    val))
    ",1).

tst:is_local_test(let_tagbody,
"(defun fifteen ()
  (let (val)
    (tagbody
      (setq val 1)
      (go point-a)
      (incf val 16)
     point-c
      (incf val 04)
      (go point-b)
      (incf val 32)
     point-a
     point-u ;; unused
      (incf val 02)
      (go point-c)
      (incf val 64)
     point-b
      (incf val 08)
      (print val)
      )
    val)
    )
    ",15).

 % [let,[val],[tagbody,[setq,val,1],[go,'point-a'],[incf,val,16],'point-c',[incf,val,4],[go,'point-b'],[incf,val,32],
   % 'point-a',[incf,val,2],[go,'point-c'],[incf,val,64], 
   % 'point-b',[incf,val,8]],val]


%:- forall(clause(block_tagbody_test(_N),B),B).


:- fixup_exports.

/*
   call_addr_block(Env,
     (symbol_setq(val, 1, _1398), goto(Result,'point-a')),
       [addr('point-c', '$used',  (sym_arg_val_env(val, Val_In, Val_Thru, LETENV), incf(Val_Thru, 4, Incf_Ret), goto(Result,'point-b'))), 
        addr('point-a', '$used',  (push_label('point-d-unused'), sym_arg_val_env(val, Val_In12, Val_Thru13, LETENV), incf(Val_Thru13, 2, Incf_Ret14), goto(Result,'point-c'))), 
        addr('point-d-unused', '$unused',  (sym_arg_val_env(val, Val_In17, Val_Thru18, LETENV), incf(Val_Thru18, 2, Incf_Ret19), goto(Result,'point-c'))), 
        addr('point-b', '$used', ['point-b', [incf, val, 8]])], _GORES15),
   sym_arg_val_env(val, Val_In22, Val_Thru23, LETENV)

      */

end_of_file.


(defpackage "TB"
  (:use "CL")
  (:shadow "TAGBODY" "GO"))

(in-package "TB")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun split-tagbody (body)
    (loop
      :with chunks := '()
      :with chunk := '()
      :for item :in body
      :if (symbolp item)
        :do (push (nreverse chunk) chunks)
            (setf chunk (list item))
      :else
        :do (push item chunk)
      :finally (push (nreverse chunk) chunks)
               (return (nreverse chunks)))))

(defmacro go (name)
  `(error "Cannot (go ~S) from outside of a tagbody." ',name))

(defmacro tagbody (&body body)
  (let* ((chunks (split-tagbody body))
         (tags   (mapcar (lambda (chunk)
                           (let ((tag (first chunk)))
                             (cons tag
                                   (make-symbol (format nil "tag-~S" tag)))))
                         (rest chunks)))
         (exit (make-symbol "exit")))
    (flet ((expand-go (name)
             (list (or (cdr (assoc name tags))
                       (error "Unknown tag ~S" name)))))
      `(macrolet ((go (name)
                    (let ((fun (cdr (assoc name ',tags))))
                      (if fun
                          `(,fun)
                          (error "Unknown tag ~S" name)))))
         (block ,exit
           (labels ,(mapcar (lambda (chunk next-chunk)
                              (destructuring-bind (name &rest body) chunk
                                `(,(cdr (assoc name tags)) ()
                                  ,@body
                                  ,(if next-chunk
                                       (expand-go (first next-chunk))
                                       `(return-from ,exit nil)))))
                            (rest chunks) (append (rest (rest chunks)) '(())))
             ,@(first chunks)
             ,(expand-go (first (first (rest chunks))))))))))


(pprint
 (macroexpand-1 '(tagbody
                  (print 'begin)
                  (go test)
                  loop
                  (print 'hi)
                  (print 'lo)
                  end-of-loop
                  test
                  (if (plusp (decf foo))
                      (go loop)))))

(macrolet ((go (name)
             (let ((fun
                    (cdr (assoc name
                                '((loop . #1=#:|tag-loop|) (end-of-loop . #2=#:|tag-end-of-loop|)
                                  (test . #3=#:|tag-test|))))))
               (if fun (list fun) (error "Unknown tag ~S" name)))))
  (block #4=#:|exit|
    (labels ((#1# nil (print 'hi) (print 'lo) (#2#))
             (#2# nil (#3#))
             (#3# nil (if (plusp (decf foo)) (go loop)) (return-from #4# nil)))
      (print 'begin)
      (go test)
      (#1#))))




(let ((i 3))
  (tagbody
     (print 'begin)
     (go test)
   loop
     (print 'hi)
     (print 'lo)
   end-of-loop
   test
     (if (plusp (decf i))
         (go loop))))




__        ___    __  __        ____ _
\ \      / / \  |  \/  |      / ___| |
 \ \ /\ / / _ \ | |\/| |_____| |   | |
  \ V  V / ___ \| |  | |_____| |___| |___
   \_/\_/_/   \_\_|  |_|      \____|_____|

Common Lisp, written in Prolog
> ^DTerminating WAM-CL
?- compile_test(X,Y,Z,Q),dbmsg(Y),call(Y).
/*
:- lisp_compiled_eval(
                      [ defun,
                        sum_with_map,
                        [xs],

                        [ let,
                          [[running_total, 0]],

                          [ let,

                            [
                              [ summer,

                                [ function,

                                  [ lambda,
                                    [n],
                                    [setq, running_total, [+, running_total, n]]
                                  ]
                                ]
                              ]
                            ],
                            [mapcar, summer, xs],
                            running_total
                          ]
                        ]
                      ]).
*/
( defun sum_with_map ( xs ) ( let ( ( running_total 0 ) ) ( let ( ( summer # ' ( lambda ( n ) ( setq running_total ( + running_total n ) ) ) ) ) ( mapcar summer xs ) running_total ) ) )
/*
dbmsg(asserta, sum_with_map(Xs_In, RETRunning_total_Thru23)) :-
        fail,
        ( [sum_with_map, xs]<<==[[let, [[running_total, 0]], [let, [[summer, [function, [lambda, [n], [setq, running_total, [+, running_total, n]]]]]], [mapcar, summer, xs], running_total]]]
        ).
dbmsg(asserta, sum_with_map(Xs_In, RETRunning_total_Thru23)) :- !,
        DEnv=[[bv(xs, [Xs_In|__])]],
        LETENV=[[bv(running_total, [0|_178])]|DEnv],
        LETENV15=[[bv(summer, [[closure, [n], [LEnv, LResultVv_c43__Ret]^(sym_arg_val_env(running_total, Running_total_In, Running_total_Thru, LEnv), sym_arg_val_env(n, N_In, N_Thru, LEnv), +(Running_total_Thru, N_Thru, LResultVv_c43__Ret), symbol_setter(setq, running_total, LResultVv_c43__Ret, LEnv)), LETENV]|_378])]|LETENV],
        sym_arg_val_env(summer, Summer_In, Summer_Thru, LETENV15),
        sym_arg_val_env(xs, Xs_In, Xs_Thru, LETENV15),
        mapcar(Summer_Thru, Xs_Thru, Mapcar_Ret),
        sym_arg_val_env(running_total,
                        Running_total_In22,
                        RETRunning_total_Thru23,
                        LETENV15).
*/
Y =  (asserta((sum_with_map(_548, _616):-fail, ([sum_with_map, xs]<<==[[let, [[...|...]], [...|...]]]))), asserta((sum_with_map(_548, _616):-!, _174=[[bv(xs, [...|...])]], _180=[[bv(..., ...)]|_174], _422=[[...]|...], sym_arg_val_env(summer, _480, _466, _422), sym_arg_val_env(..., ..., ..., ...), ..., ...))),
Z = sum_with_map ;
/*
:- lisp_compiled_eval(
                      [ defun,
                        sum_with_map,
                        [xs],

                        [ let,
                          [[running_total, 0]],

                          [ let,

                            [
                              [ summer,

                                [ function,

                                  [ lambda,
                                    [n],
                                    [setq, running_total, [+, running_total, n]]
                                  ]
                                ]
                              ]
                            ],
                            [mapcar, summer, xs],
                            running_total
                          ]
                        ]
                      ]).
*/
( defun sum_with_map ( xs ) ( let ( ( running_total 0 ) ) ( let ( ( summer # ' ( lambda ( n ) ( setq running_total ( + running_total n ) ) ) ) ) ( mapcar summer xs ) running_total ) ) )
/*
dbmsg(asserta, sum_with_map(Xs_In, RETRunning_total_Thru23)) :-
        fail,
        ( [sum_with_map, xs]<<==[[let, [[running_total, 0]], [let, [[summer, [function, [lambda, [n], [setq, running_total, [+, running_total, n]]]]]], [mapcar, summer, xs], running_total]]]
        ).
dbmsg(asserta, sum_with_map(Xs_In, RETRunning_total_Thru23)) :- !,
        DEnv=[[bv(xs, [Xs_In|__])]],
        LETENV=[[bv(running_total, [0|_178])]|DEnv],
        LETENV15=[[bv(summer, [[closure, [n], [LEnv, LResultVv_c43__Ret]^(sym_arg_val_env(running_total, Running_total_In, Running_total_Thru, LEnv), sym_arg_val_env(n, N_In, N_Thru, LEnv), +(Running_total_Thru, N_Thru, LResultVv_c43__Ret), symbol_setter(setq, running_total, LResultVv_c43__Ret, LEnv)), LETENV]|_378])]|LETENV],
        sym_arg_val_env(summer, Summer_In, Summer_Thru, LETENV15),
        sym_arg_val_env(xs, Xs_In, Xs_Thru, LETENV15),
        mapcar(Summer_Thru, Xs_Thru, Mapcar_Ret),
        sym_arg_val_env(running_total,
                        Running_total_In22,
                        RETRunning_total_Thru23,
                        LETENV15).
*/
Y =  (asserta((sum_with_map(_548, _616):-fail, ([sum_with_map, xs]<<==[[let, [[...|...]], [...|...]]]))), asserta((sum_with_map(_548, _616):-!, _174=[[bv(xs, [...|...])]], _180=[[bv(..., ...)]|_174], _422=[[...]|...], sym_arg_val_env(summer, _480, _466, _422), sym_arg_val_env(..., ..., ..., ...), ..., ...))),
Z = sum_with_map ;
/*
:- lisp_compiled_eval(
                      [ defun,
                        accumulate,
                        [op, seq, '&optional', [init, 0]],

                        [ if,
                          [null, seq],
                          init,

                          [ funcall,
                            op,
                            [car, seq],
                            [accumulate, op, [cdr, seq], init]
                          ]
                        ]
                      ]).
*/
( defun accumulate ( op seq &optional ( init 0 ) ) ( if ( null seq ) init ( funcall op ( car seq ) ( accumulate op ( cdr seq ) init ) ) ) )
/*
dbmsg(asserta, accumulate(Op_In19, Seq_In22, Vv_c38_optional, InitVv0, RET)) :-
        fail,
        ( [accumulate, op, seq, '&optional', [init, 0]]<<==[[if, [null, seq], init, [funcall, op, [car, seq], [accumulate, op, [cdr, seq], init]]]]
        ).
dbmsg(asserta, accumulate(Op_In19, Seq_In22, Vv_c38_optional, InitVv0, RET)) :- !,
        DEnv=[[bv(op, [Op_In19|__]), bv(seq, [Seq_In22|__]), bv('&optional', [Vv_c38_optional|_414]), bv([init, 0], [InitVv0|_430])]],
        sym_arg_val_env(seq, Seq_In22, IFSeq_Thru, DEnv),
        (   IFSeq_Thru==[]
        ->  sym_arg_val_env(init, Init_In, Init_Thru, DEnv),
            RET=Init_Thru
        ;   sym_arg_val_env(op, Op_In19, Op_Thru, DEnv),
            symbol_value(seq, DEnv, Seq_Thru17),
            car(Seq_Thru17, Car_Ret),
            symbol_value(op, DEnv, Op_Thru20),
            symbol_value(seq, DEnv, Seq_Thru23),
            cdr(Seq_Thru23, Cdr_Ret),
            sym_arg_val_env(init, Init_In25, Init_Thru26, DEnv),
            accumulate(Op_Thru20, Cdr_Ret, Init_Thru26, Accumulate_Ret),
            funcall(Op_Thru, Car_Ret, Accumulate_Ret, Funcall_Ret),
            RET=Funcall_Ret
        ).
*/
Y =  (asserta((accumulate(_660, _518, _412, _428, _444):-fail, ([accumulate, op, seq, '&optional'|...]<<==[[if, [null|...], init|...]]))), asserta((accumulate(_660, _518, _412, _428, _444):-!, _458=[[bv(op, [...|...]), bv(..., ...)|...]], sym_arg_val_env(seq, _518, _504, _458), (_504==[]->sym_arg_val_env(..., ..., ..., ...), ... = ...;sym_arg_val_env(op, _660, _646, _458), symbol_value(..., ..., ...), ..., ...)))),
Z = accumulate ;
/*
:- lisp_compiled_eval(
                      [ let,
                        [b],

                        [ tagbody,
                          [setq, b, 2],
                          [go, tag2],
                          [setq, a, 1],
                          tag1,
                          [setq, b, 3],
                          [go, tag3],
                          tag2,
                          [setq, a, 4],
                          [go, tag1],
                          tag3,
                          [print, ['1+', [plus, a, b]]]
                        ],
                        b
                      ]).
*/
( let ( b ) ( tagbody ( setq b 2 ) ( go tag2 ) ( setq a 1 ) tag1 ( setq b 3 ) ( go tag3 ) tag2 ( setq a 4 ) ( go tag1 ) tag3 ( print ( 1+ ( plus a b ) ) ) ) b )
/*
:- GoEnvLETENV=[[bv(b, [[]|_942])]|toplevel],
   call_addr_block(GoEnvLETENV,
                   (symbol_setter(setq, b, 2, GoEnvLETENV), goto(tag2, [], GoEnvLETENV)),

                   [ addr(tag1,
                          '$used',
                          _6250,
                          (symbol_setter(setq, b, 3, _6250), goto(tag3, [], _6250))),
                     addr(tag2,
                          '$used',
                          _6296,
                          (symbol_setter(setq, a, 4, _6296), goto(tag1, [], _6296))),
                     addr(tag3,
                          '$used',
                          _6344,
                          (sym_arg_val_env(a, _6358, _6360, _6344), sym_arg_val_env(b, _6374, _6376, _6344), plus(_6360, _6376, _6392), '1+'(_6392, _6404), print(_6404, _6414)))
                   ],
                   _GORES18),
   sym_arg_val_env(b, B_In20, B_Thru21, GoEnvLETENV).
*/
8
X = tagbody_let3,
Y =  ([[bv(b, [2|_150])]|toplevel]=[[bv(b, [2|_150])]|toplevel], call_addr_block([[bv(b, [2|_150])]|toplevel],  (symbol_setter(setq, b, 2, [[bv(b, [2|...])]|toplevel]), goto(tag2, [], [[bv(b, [2|...])]|toplevel])), [addr(tag1, '$used', _528,  (symbol_setter(setq, b, 3, _528), goto(tag3, [], _528))), addr(tag2, '$used', _532,  (symbol_setter(setq, a, 4, _532), goto(tag1, [], _532))), addr(tag3, '$used', _544,  (sym_arg_val_env(a, _546, _548, _544), sym_arg_val_env(..., ..., ..., ...), ..., ...))], []), sym_arg_val_env(b, 2, 2, [[bv(b, [2|_150])]|toplevel])),
Z = 2,
Q = 3 ;
/*
:- lisp_compiled_eval(
                      [ tagbody,
                        [setq, b, 2],
                        [go, tag2],
                        [setq, a, 1],
                        tag1,
                        [setq, b, 3],
                        [go, tag3],
                        tag2,
                        [setq, a, 4],
                        [go, tag1],
                        tag3,
                        [print, ['1+', [plus, a, b]]]
                      ]).
*/
( tagbody ( setq b 2 ) ( go tag2 ) ( setq a 1 ) tag1 ( setq b 3 ) ( go tag3 ) tag2 ( setq a 4 ) ( go tag1 ) tag3 ( print ( 1+ ( plus a b ) ) ) )
/*
:- call_addr_block(toplevel,
                   (symbol_setter(setq, b, 2, toplevel), goto(tag2, [], toplevel)),

                   [ addr(tag1,
                          '$used',
                          _11024,
                          (symbol_setter(setq, b, 3, _11024), goto(tag3, [], _11024))),
                     addr(tag2,
                          '$used',
                          _11070,
                          (symbol_setter(setq, a, 4, _11070), goto(tag1, [], _11070))),
                     addr(tag3,
                          '$used',
                          _11118,
                          (sym_arg_val_env(a, _11132, _11134, _11118), sym_arg_val_env(b, _11148, _11150, _11118), plus(_11134, _11150, _11166), '1+'(_11166, _11178), print(_11178, _11188)))
                   ],
                   _GORES16).
*/
8
X = tagbody7_prints_8,
Y = call_addr_block(toplevel,  (symbol_setter(setq, b, 2, toplevel), goto(tag2, [], toplevel)), [addr(tag1, '$used', _466,  (symbol_setter(setq, b, 3, _466), goto(tag3, [], _466))), addr(tag2, '$used', _470,  (symbol_setter(setq, a, 4, _470), goto(tag1, [], _470))), addr(tag3, '$used', _472,  (sym_arg_val_env(a, _474, _476, _472), sym_arg_val_env(b, _478, _480, _472), plus(_476, _480, _482), '1+'(..., ...), print(..., ...)))], []),
Z = [],
Q = 7 ;
/*
:- lisp_compiled_eval(
                      [ do,

                        [ ['temp-one', 1, ['1+', 'temp-one']],
                          ['temp-two', 0, ['1-', 'temp-two']]
                        ],
                        [[>, [-, 'temp-one', 'temp-two'], 5], 'temp-one']
                      ]).
*/
( do ( ( temp-one 1 ( 1+ temp-one ) ) ( temp-two 0 ( 1- temp-two ) ) ) ( ( > ( - temp-one temp-two ) 5 ) temp-one ) )
/*
;:- call_addr_block(toplevel,
                   goto(enter([]), [], toplevel),

                   [ addr(enter([]),
                          '$used',
                          _1574,
                          (_1600=[[bv('temp-one', [1|_1634]), bv('temp-two', [0|_1652])]|_1574], call_addr_block(_1600,  (push_label(dosym1), sym_arg_val_env('temp-one', _1694, _1708, _1600), sym_arg_val_env('temp-two', _1738, _1752, _1600), -(_1708, _1752, _1780), >(_1780, 5, _1808), (_1808\=[]->sym_arg_val_env('temp-one', _1862, _1876, _1600), goto(exit([]), _1876, _1600), _1904=_1910;sym_arg_val_env('temp-one', _1940, _1954, _1600), '1+'(_1954, _1980), sym_arg_val_env('temp-two', _2010, _2024, _1324), '1-'(_1386, _1390), symbol_setter(psetq, 'temp-one', _1378, _1324), symbol_setter(psetq, 'temp-two', _1390, _1324), _1362=[[_1378, _1390]]), goto(dosym1, [], _1324)), [addr(dosym1, '$unused', _1392,  (sym_arg_val_env('temp-one', _1394, _1396, _1392), sym_arg_val_env('temp-two', _1398, _1400, _1392), -(_1396, _1400, _1402), >(_1402, 5, _1406), (_1406\=[]->sym_arg_val_env('temp-one', _1410, _1414, _1392), goto(exit([]), _1414, _1392), _1416=_1418;sym_arg_val_env('temp-one', _1422, _1426, _1392), '1+'(_1426, _1428), sym_arg_val_env('temp-two', _1432, _1436, _1392), '1-'(_1436, _1438), symbol_setter(psetq, 'temp-one', _1428, _1392), symbol_setter(psetq, 'temp-two', _1438, _1392), _1416=[[_1428, _1438]]), goto(dosym1, [], _1392)))], _1442), goto(exit([]), [], _1320))),
                     addr(exit([]), '$used', _1444, true)
                   ],
                   []).
*/
X = do(0.0),
Y = call_addr_block(toplevel, goto(enter([]), [], toplevel), [addr(enter([]), '$used', _1318,  (_1320=[[bv('temp-one', [1|...]), bv('temp-two', [...|...])]|_1318], call_addr_block(_1320,  (push_label(dosym1), sym_arg_val_env('temp-one', _1326, _1328, _1320), sym_arg_val_env(..., ..., ..., ...), ..., ...), [addr(dosym1, '$unused', _1358,  (sym_arg_val_env(..., ..., ..., ...), ..., ...))], _1392), goto(exit([]), [], _1318))), addr(exit([]), '$used', _1394, true)], []),
Z = [],
Q = 4 ;
/*
:- lisp_compiled_eval(
                      [ do,

                        [ ['temp-one', 1, ['1+', 'temp-one']],
                          ['temp-two', 0, ['1+', 'temp-one']]
                        ],
                        [[=, 3, 'temp-two'], 'temp-one']
                      ]).
*/
( do ( ( temp-one 1 ( 1+ temp-one ) ) ( temp-two 0 ( 1+ temp-one ) ) ) ( ( = 3 temp-two ) temp-one ) )
/*
;:- call_addr_block(toplevel,
                   goto(enter([]), [], toplevel),

                   [ addr(enter([]),
                          '$used',
                          _1396,
                          (_1422=[[bv('temp-one', [1|_1456]), bv('temp-two', [0|_1474])]|_1396], call_addr_block(_1422,  (push_label(dosym2), sym_arg_val_env('temp-two', _1516, _1530, _1422), =(3, _1530, _1558), (_1558\=[]->sym_arg_val_env('temp-one', _1612, _1626, _1422), goto(exit([]), _1626, _1422), _1654=_1660;sym_arg_val_env('temp-one', _1690, _1704, _1422), '1+'(_1704, _1730), sym_arg_val_env('temp-one', _1760, _1774, _1422), '1+'(_1774, _1800), symbol_setter(psetq, 'temp-one', _1730, _1422), symbol_setter(psetq, 'temp-two', _1800, _1422), _1654=[[_1730, _1800]]), goto(dosym2, [], _1422)), [addr(dosym2, '$unused', _1888,  (sym_arg_val_env('temp-two', _1902, _1904, _1888), =(3, _1904, _1924), (_1924\=[]->sym_arg_val_env('temp-one', _1970, _1978, _1888), goto(exit([]), _1978, _1888), _2006=_2008;sym_arg_val_env('temp-one', _2028, _2042, _1888), '1+'(_2042, _2064), sym_arg_val_env('temp-one', _2084, _2098, _1888), '1+'(_2098, _2124), symbol_setter(psetq, 'temp-one', _2064, _1888), symbol_setter(psetq, 'temp-two', _2124, _1888), _2006=[[_2064, _2124]]), goto(dosym2, [], _1888)))], _1266), goto(exit([]), [], _1162))),
                     addr(exit([]), '$used', _1268, true)
                   ],
                   []).
*/
X = do(0.1),
Y = call_addr_block(toplevel, goto(enter([]), [], toplevel), [addr(enter([]), '$used', _1160,  (_1162=[[bv('temp-one', [1|...]), bv('temp-two', [...|...])]|_1160], call_addr_block(_1162,  (push_label(dosym2), sym_arg_val_env('temp-two', _1168, _1170, _1162), =(..., ..., ...), ..., ...), [addr(dosym2, '$unused', _1194,  (sym_arg_val_env(..., ..., ..., ...), ..., ...))], _1222), goto(exit([]), [], _1160))), addr(exit([]), '$used', _1224, true)], []),
Z = [],
Q = 3 ;
/*
:- lisp_compiled_eval(
                      [ tagbody,
                        [setq, b, 2],
                        [go, tag1],
                        [setq, a, 1],
                        tag1,
                        [setq, a, 4],
                        [print, [plus, a, b]]
                      ]).
*/
( tagbody ( setq b 2 ) ( go tag1 ) ( setq a 1 ) tag1 ( setq a 4 ) ( print ( plus a b ) ) )
/*
:- call_addr_block(toplevel,
                   (symbol_setter(setq, b, 2, toplevel), goto(tag1, [], toplevel)),

                   [ addr(tag1,
                          '$used',
                          _340,
                          (symbol_setter(setq, a, 4, _340), sym_arg_val_env(a, _342, _344, _340), sym_arg_val_env(b, _346, _348, _340), plus(_344, _348, _350), print(_350, _352)))
                   ],
                   Z).
*/
6
X = tagbody1,
Y = call_addr_block(toplevel,  (symbol_setter(setq, b, 2, toplevel), goto(tag1, [], toplevel)), [addr(tag1, '$used', _340,  (symbol_setter(setq, a, 4, _340), sym_arg_val_env(a, _342, _344, _340), sym_arg_val_env(b, _346, _348, _340), plus(_344, _348, _350), print(_350, _352)))], []),
Z = Q, Q = [] ;
/*
:- lisp_compiled_eval(
                      [ block,
                        block3,
                        [setq, b, 2],
                        [go, tag1],
                        [setq, a, 1],
                        tag1,
                        [setq, a, 4],
                        [print, [plus, a, b]],
                        ['return-from', block3, [plus, a, b]]
                      ]).
*/
( block block3 ( setq b 2 ) ( go tag1 ) ( setq a 1 ) tag1 ( setq a 4 ) ( print ( plus a b ) ) ( return-from block3 ( plus a b ) ) )
/*
:- call_addr_block(toplevel,
                   goto(enter(block3), [], toplevel),

                   [ addr(enter(block3),
                          '$used',
                          _14882,
                          (symbol_setter(setq, b, 2, _14882), goto(tag1, [], _14882))),
                     addr(tag1,
                          '$used',
                          _14922,
                          (symbol_setter(setq, a, 4, _14922), sym_arg_val_env(a, _620, _622, _618), sym_arg_val_env(b, _624, _626, _618), plus(_622, _626, _628), print(_628, _630), sym_arg_val_env(a, _634, _638, _618), sym_arg_val_env(b, _642, _646, _618), plus(_638, _646, _650), goto(exit(block3), _650, _618))),
                     addr(exit(block3), '$used', _652, true)
                   ],
                   []).
*/
6
X = block3,
Y = call_addr_block(toplevel, goto(enter(block3), [], toplevel), [addr(enter(block3), '$used', _616,  (symbol_setter(setq, b, 2, _616), goto(tag1, [], _616))), addr(tag1, '$used', _618,  (symbol_setter(setq, a, 4, _618), sym_arg_val_env(a, _620, _622, _618), sym_arg_val_env(b, _624, _626, _618), plus(_622, _626, _628), print(..., ...), ..., ...)), addr(exit(block3), '$used', _652, true)], []),
Z = [],
Q = 6 ;
/*
:- lisp_compiled_eval([defun, let_simple, [], [let, [val], val]]).
*/
( defun let_simple NIL ( let ( val ) val ) )
/*
dbmsg(asserta, let_simple(RETVal_Thru)) :-
        fail,
        ( [let_simple]<<==[[let, [val], val]]
        ).
dbmsg(asserta, let_simple(RETVal_Thru)) :- !,
        DEnv=[[]],
        LETENV=[[bv(val, [[]|_1024])]|DEnv],
        sym_arg_val_env(val, Val_In, RETVal_Thru, LETENV).
*/
X = Z, Z = let_simple,
Y =  (asserta((let_simple(_3888):-fail, ([let_simple]<<==[[let, [val], val]]))), asserta((let_simple(_3888):-!, _560=[[]], _1072=[[bv(..., ...)]|_560], sym_arg_val_env(val, _3902, _3888, _1072)))),
Q = [] ;
/*
:- lisp_compiled_eval([defun, let_simple1, [], [let, [[val, 1]], val]]).
*/
( defun let_simple1 NIL ( let ( ( val 1 ) ) val ) )
/*
dbmsg(asserta, let_simple1(RETVal_Thru)) :-
        fail,
        ( [let_simple1]<<==[[let, [[val, 1]], val]]
        ).
dbmsg(asserta, let_simple1(RETVal_Thru)) :- !,
        DEnv=[[]],
        LETENV=[[bv(val, [1|_1034])]|DEnv],
        sym_arg_val_env(val, Val_In, RETVal_Thru, LETENV).
*/
X = Z, Z = let_simple1,
Y =  (asserta((let_simple1(_3898):-fail, ([let_simple1]<<==[[let, [[...|...]], val]]))), asserta((let_simple1(_3898):-!, _570=[[]], _1082=[[bv(..., ...)]|_570], sym_arg_val_env(val, _3912, _3898, _1082)))),
Q = 1 ;
/*
:- lisp_compiled_eval(
                      [ defun,
                        fifteen,
                        [],

                        [ let,
                          [val],

                          [ tagbody,
                            [setq, val, 1],
                            [go, 'point-a'],
                            [incf, val, 16],
                            'point-c',
                            [incf, val, 4],
                            [go, 'point-b'],
                            [incf, val, 32],
                            'point-a',
                            'point-u',
                            [incf, val, 2],
                            [go, 'point-c'],
                            [incf, val, 64],
                            'point-b',
                            [incf, val, 8]
                          ],
                          val
                        ]
                      ]).
*/
( defun fifteen NIL ( let ( val ) ( tagbody ( setq val 1 ) ( go point-a ) ( incf val 16 ) point-c ( incf val 4 ) ( go point-b ) ( incf val 32 ) point-a point-u ( incf val 2 ) ( go point-c ) ( incf val 64 ) point-b ( incf val 8 ) ) val ) )
/*
dbmsg(asserta, fifteen(RETVal_Thru)) :-
        fail,
        ( [fifteen]<<==[[let, [val], [tagbody, [setq, val, 1], [go, 'point-a'], [incf, val, 16], 'point-c', [incf, val, 4], [go, 'point-b'], [incf, val, 32], 'point-a', 'point-u', [incf, val, 2], [go, 'point-c'], [incf, val, 64], 'point-b', [incf, val, 8]], val]]
        ).
dbmsg(asserta, fifteen(RETVal_Thru)) :- !,
        DEnv=[[]],
        GoEnvLETENV=[[bv(val, [[]|_152])]|DEnv],
        call_addr_block(GoEnvLETENV,
                        (symbol_setter(setq, val, 1, GoEnvLETENV), goto('point-a', [], GoEnvLETENV)),

                        [ addr('point-c',
                               '$used',
                               _416,
                               (place_op(incf, val, [4], _416, _418), goto('point-b', [], _416))),
                          addr('point-a',
                               '$used',
                               _422,
                               (push_label('point-u'), place_op(incf, val, [2], _422, _434), goto('point-c', [], _422))),
                          addr('point-u',
                               '$unused',
                               _438,
                               (place_op(incf, val, [2], _438, _450), goto('point-c', [], _438))),
                          addr('point-b',
                               '$used',
                               _452,
                               place_op(incf, val, [8], _452, _456))
                        ],
                        _GORES14),
        sym_arg_val_env(val, Val_In, RETVal_Thru, GoEnvLETENV).
*/
X = let_tagbody,
Y =  (asserta((fifteen(_496):-fail, ([fifteen]<<==[[let, [val], [...|...]|...]]))), asserta((fifteen(_496):-!, _148=[[]], _402=[[bv(..., ...)]|_148], call_addr_block(_402,  (symbol_setter(..., ..., ..., ...), goto(..., ..., ...)), [addr(..., ..., ..., ...)|...], _260), sym_arg_val_env(val, _498, _496, _402)))),
Z = fifteen,
Q = 15.

