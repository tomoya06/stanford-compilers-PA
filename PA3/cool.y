/*
*  cool.y
*              Parser definition for the COOL language.
*
*/
%{
  #include <iostream>
  #include "cool-tree.h"
  #include "stringtab.h"
  #include "utilities.h"
  
  extern char *curr_filename;
  
  
  /* Locations */
  #define YYLTYPE int              /* the type of locations */
  #define cool_yylloc curr_lineno  /* use the curr_lineno from the lexer
                                      for the location of tokens */
    
    extern int node_lineno;          /* set before constructing a tree node
                                        to whatever you want the line number
                                        for the tree node to be */
      
      
      #define YYLLOC_DEFAULT(Current, Rhs, N)         \
      Current = Rhs[1];                             \
      node_lineno = Current;
    
    
    #define SET_NODELOC(Current)  \
    node_lineno = Current;
    
    /* IMPORTANT NOTE ON LINE NUMBERS
    *********************************
    * The above definitions and macros cause every terminal in your grammar to 
    * have the line number supplied by the lexer. The only task you have to
    * implement for line numbers to work correctly, is to use SET_NODELOC()
    * before constructing any constructs from non-terminals in your grammar.
    * Example: Consider you are matching on the following very restrictive 
    * (fictional) construct that matches a plus between two integer constants. 
    * (SUCH A RULE SHOULD NOT BE  PART OF YOUR PARSER):
    
    plus_consts	: INT_CONST '+' INT_CONST 
    
    * where INT_CONST is a terminal for an integer constant. Now, a correct
    * action for this rule that attaches the correct line number to plus_const
    * would look like the following:
    
    plus_consts	: INT_CONST '+' INT_CONST 
    {
      // Set the line number of the current non-terminal:
      // ***********************************************
      // You can access the line numbers of the i'th item with @i, just
      // like you acess the value of the i'th exporession with $i.
      //
      // Here, we choose the line number of the last INT_CONST (@3) as the
      // line number of the resulting expression (@$). You are free to pick
      // any reasonable line as the line number of non-terminals. If you 
      // omit the statement @$=..., bison has default rules for deciding which 
      // line number to use. Check the manual for details if you are interested.
      @$ = @3;
      
      
      // Observe that we call SET_NODELOC(@3); this will set the global variable
      // node_lineno to @3. Since the constructor call "plus" uses the value of 
      // this global, the plus node will now have the correct line number.
      SET_NODELOC(@3);
      
      // construct the result node:
      $$ = plus(int_const($1), int_const($3));
    }
    
    */
    
    
    
    void yyerror(char *s);        /*  defined below; called for each parse error */
    extern int yylex();           /*  the entry point to the lexer  */
    
    /************************************************************************/
    /*                DONT CHANGE ANYTHING IN THIS SECTION                  */
    
    Program ast_root;	      /* the result of the parse  */
    Classes parse_results;        /* for use in semantic analysis */
    int omerrs = 0;               /* number of errors in lexing and parsing */
    %}
    
    /* A union of all the types that can be the result of parsing actions. */
    %union {
      Boolean boolean;
      Symbol symbol;
      Program program;
      Class_ class_;
      Classes classes;
      Feature feature;
      Features features;
      Formal formal;
      Formals formals;
      Case case_;
      Cases cases;
      Expression expression;
      Expressions expressions;
      char *error_msg;
    }
    
    /* 
    Declare the terminals; a few have types for associated lexemes.
    The token ERROR is never used in the parser; thus, it is a parse
    error when the lexer returns it.
    
    The integer following token declaration is the numeric constant used
    to represent that token internally.  Typically, Bison generates these
    on its own, but we give explicit numbers to prevent version parity
    problems (bison 1.25 and earlier start at 258, later versions -- at
    257)
    */
    %token CLASS 258 ELSE 259 FI 260 IF 261 IN 262 
    %token INHERITS 263 LET 264 LOOP 265 POOL 266 THEN 267 WHILE 268
    %token CASE 269 ESAC 270 OF 271 DARROW 272 NEW 273 ISVOID 274
    %token <symbol>  STR_CONST 275 INT_CONST 276 
    %token <boolean> BOOL_CONST 277
    %token <symbol>  TYPEID 278 OBJECTID 279 
    %token ASSIGN 280 NOT 281 LE 282 ERROR 283
    
    /*  DON'T CHANGE ANYTHING ABOVE THIS LINE, OR YOUR PARSER WONT WORK       */
    /**************************************************************************/
    
    /* Complete the nonterminal list below, giving a type for the semantic
    value of each non terminal. (See section 3.6 in the bison 
    documentation for details). */

    /* Left-associativity */
    %right ASSIGN
    %left '-' '+'
    %left '*' '/'
    %left '~'
    %left ISVOID
    %left NOT
    %nonassoc '=' LE '<'
    
    /* Declare types for the grammar's non-terminals. */
    %type <program> program
    %type <classes> class_list
    %type <class_> class
    
    /* You will want to change the following line. */
    %type <features> serial_feature_list
    %type <feature> single_feature

    %type <formals> dummy_formal_list
    %type <formal> single_formal

    %type <expression> single_expression

    %type <expressions> dummy_expression_list
    %type <expressions> serial_expression_list

    %type <expression> inner_let_expression

    %type <cases> dummy_case_list

    
    /* Precedence declarations go here. */
    
    
    %%
    /* 
    Save the root of the abstract syntax tree in a global variable.
    */
    program	: class_list	{ @$ = @1; ast_root = program($1); }
    ;
    
    class_list
    : class			                                                      /* single class */
    { $$ = single_Classes($1); parse_results = $$; }
    | class_list class	                                               /* several classes */
    { $$ = append_Classes($1,single_Classes($2)); parse_results = $$; }
    ;
    
    /* If no parent is specified, the class inherits from the Object class. */
    class	
    : CLASS TYPEID '{' serial_feature_list '}' ';'
    { $$ = class_($2,idtable.add_string("Object"),$4,stringtable.add_string(curr_filename)); }
    | CLASS TYPEID INHERITS TYPEID '{' serial_feature_list '}' ';'
    { $$ = class_($2,$4,$6,stringtable.add_string(curr_filename)); }
    | error
    {}
    ;
    
    /* Feature list may be empty, but no empty features in list. */
    serial_feature_list:
    { $$ = nil_Features(); }
    | single_feature ';' serial_feature_list
    { $$ = append_Features(single_Features($1), $3); }
    ;

    single_feature
    : OBJECTID '(' dummy_formal_list ')' ':' TYPEID '{' single_expression '}'
    { $$ = method($1,$3,$6,$8); }
    | OBJECTID ':' TYPEID
    { $$ = attr($1,$3,no_expr()); }
    | OBJECTID ':' TYPEID ASSIGN single_expression
    { $$ = attr($1,$3,$5); }
    | error
    {}
    ;

    /* Formals */
    dummy_formal_list
    : { $$ = nil_Formals(); }
    | single_formal
    { $$ = single_Formals($1); }
    | single_formal ',' dummy_formal_list
    { $$ = append_Formals(single_Formals($1), $3); }
    ;

    single_formal
    : OBJECTID ':' TYPEID 
    { $$ = formal($1,$3); }
    ;

    /* expressions */
    single_expression
    : OBJECTID ASSIGN single_expression                                    /* assign */
    { $$ = assign($1,$3); }
    | single_expression '.' OBJECTID '(' dummy_expression_list ')'    /* dispatch */
    { $$ = dispatch($1,$3,$5); }
    | single_expression '@' TYPEID '.' OBJECTID '(' dummy_expression_list ')'    /* static_dispatch */
    { $$ = static_dispatch($1,$3,$5,$7); }
    | OBJECTID '(' dummy_expression_list ')'                                  /* self dispatch */
    { $$ = dispatch(object(idtable.add_string("self")),$1,$3); }
    | IF single_expression THEN single_expression ELSE single_expression FI    /* if cond */
    { $$ = cond($2, $4, $6); }
    | WHILE single_expression LOOP single_expression POOL                 /* loop */
    { $$ = loop($2, $4); }
    | WHILE single_expression LOOP error
    {}
    | '{' serial_expression_list '}'                                           /* block */
    { $$ = block($2); }
    | LET inner_let_expression                                        /* let */ 
    { $$ = $2; }
    | CASE single_expression OF dummy_case_list ESAC       /* typcase */
    { $$ = typcase($2,$4); }
    | NEW TYPEID                                                      /* new_ */
    { $$ = new_($2); }
    | ISVOID single_expression                                        /* isvoid */
    { $$ = isvoid($2); }
    | single_expression '+' single_expression                           /* plus */
    { $$ = plus($1,$3); }
    | single_expression '-' single_expression                             /* sub */
    { $$ = sub($1,$3); }
    | single_expression '*' single_expression                           /* mul */
    { $$ = mul($1,$3); }
    | single_expression '/' single_expression                             /* divide */
    { $$ = divide($1,$3); }
    | '~' single_expression                                    /* neg */
    { $$ = neg($2); }
    | single_expression '<' single_expression                   /* lt */
    { $$ = lt($1,$3); }
    | single_expression '<' '=' single_expression             /* leq */
    { $$ = leq($1,$4); }
    | single_expression '=' single_expression             /* eq */
    { $$ = eq($1,$3); }
    | NOT single_expression                             /* comp */
    { $$ = comp($2); }
    | '(' single_expression ')'                         /* () */
    { $$ = $2; }
    | OBJECTID                                        /* object */
    { $$ = object($1); }
    | INT_CONST                                       /* int_const */
    { $$ = int_const($1); }
    | STR_CONST                                           /* string_const */
    { $$ = string_const($1); }
    | BOOL_CONST                                        /* bool_const */
    { $$ = bool_const($1); }
    | error
    { }
    ;

    dummy_expression_list
    : dummy_expression_list ',' single_expression 
    { $$ = append_Expressions($1,single_Expressions($3)); }
    | single_expression
    { $$ = single_Expressions($1); }
    |
    { $$ = nil_Expressions(); }                                     /* empty */
    ;
    
    serial_expression_list
    : single_expression ';' serial_expression_list
    { $$ = append_Expressions(single_Expressions($1),$3); }
    | single_expression ';'
    { $$ = single_Expressions($1); }
    ;

    inner_let_expression
    : OBJECTID ':' TYPEID ASSIGN single_expression IN single_expression
    { $$ = let($1,$3,$5,$7); }
    | OBJECTID ':' TYPEID IN single_expression
    { $$ = let($1,$3,no_expr(),$5); }
    | OBJECTID ':' TYPEID ASSIGN single_expression ',' inner_let_expression
    { $$ = let($1,$3,$5,$7); }
    | OBJECTID ':' TYPEID ',' inner_let_expression
    { $$ = let($1,$3,no_expr(),$5); }
    ;

    dummy_case_list
    : OBJECTID ':' TYPEID DARROW single_expression ';'
    { $$ = single_Cases(branch($1,$3,$5)); }
    | dummy_case_list OBJECTID ':' TYPEID DARROW single_expression ';'
    { $$ = append_Cases($1,single_Cases(branch($2,$4,$6))); }
    ;

    /* end of grammar */
    %%
    
    /* This function is called automatically when Bison detects a parse error. */
    void yyerror(char *s)
    {
      extern int curr_lineno;
      
      cerr << "\"" << curr_filename << "\", line " << curr_lineno << ": " \
      << s << " at or near ";
      print_cool_token(yychar);
      cerr << endl;
      omerrs++;
      
      if(omerrs>50) {fprintf(stdout, "More than 50 errors\n"); exit(1);}
    }
    
    