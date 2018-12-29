/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
void addChar2String(char *yytext);
bool isKW(char* str1, char* str2);
bool isUP(char* yytext);

%}

/*
 * Define names for regular expressions here.
 */

DARROW      =>
ASSIGN      <-
DIGIT       [0-9]
LETTER      [a-zA-Z{DIGIT}_]
WS_SINLINE  [ \t]

%x comment singlecomment
%x eof
%x string strerr

%%

    int comment_depth = 0;

 /* 
  * Deal with space and tab:
  */
{WS_SINLINE}* ;

 /* 
  * New lines and EOF:
  */
\n {
    curr_lineno++;
}

<eof><<EOF>> {
    return 0;
}

 /* 
  * Single Characters:
  */
\.    { return (46); }
\,    { return (44); }
\@    { return (64); }
\~    { return (126); }
\*    { return (42); }
\/    { return (47); }
\+    { return (43); }
\-    { return (45); }
\<    { return (60); }
\=    { return (61); }
\{    { return (123); }
\}    { return (125); }
\:    { return (58); }
\;    { return (59); }
\(    { return (40);}
\)    { return (41);}

 /* 
  * Comments:
  */

-- {
    BEGIN(singlecomment);
}

<singlecomment>{

    <<EOF>> BEGIN(eof);

    \n {
        curr_lineno++;
        BEGIN(0);
    }

    [^\n]* ;

}

\(\* {
    comment_depth++;
    BEGIN(comment);
}

\*\) {
    cool_yylval.error_msg = "Unmatched *)";
    return (ERROR);
}

<comment>{
    
    <<EOF>> {
        BEGIN(eof);
        cool_yylval.error_msg = "EOF in comment";
        return (ERROR);
    }
    \n {
        curr_lineno++;
    }
    \(\* {
        comment_depth++;
    }
    \*\) {
        if (--comment_depth < 1) {
            BEGIN(0);
        }
    }
    [^\n]* ;

}

 /* 
  * String:
  */

\" BEGIN(string);

<string,strerr>{
    
    \\n {
        addChar2String("\n");
    }

    \\0 {
        addChar2String("0");
    }

    \\{WS_SINLINE}*\n {
        curr_lineno++;
        addChar2String("\\n");
    }

    \n {
        cool_yylval.error_msg = "Unterminated string constant";
        BEGIN(strerr);
    }

    \0 {
        cool_yylval.error_msg = "String contains null character";
        BEGIN(strerr);
    }

    <<EOF>> {
        cool_yylval.error_msg = "EOF in string constant";
        BEGIN(strerr);
    }

    [^\0\n\"\\]* {
        addChar2String(yytext);
    }

    \\ {
        addChar2String(yytext);
    }

    \" {
        if (YY_START == strerr) {
            BEGIN(0);
            return (ERROR);
        } else {
            BEGIN(0);
            cool_yylval.symbol = stringtable.add_string(string_buf);
            return (STR_CONST);
        }
    }

}

 /* 
  * Keywords, Boolean and ID: (without LET_STMT)
  */
{LETTER}+ {
    // KEYWORDS:
    if (isKW(yytext, "CLASS")) { return (CLASS); }  
    if (isKW(yytext, "ELSE")) { return (ELSE); }  
    if (isKW(yytext, "IF")) { return (IF); }  
    if (isKW(yytext, "FI")) { return (FI); }  
    if (isKW(yytext, "IN")) { return (IN); }  
    if (isKW(yytext, "INHERITS")) { return (INHERITS); }  
    if (isKW(yytext, "LET")) { return (LET); }  
    if (isKW(yytext, "LOOP")) { return (LOOP); }  
    if (isKW(yytext, "POOL")) { return (POOL); }  
    if (isKW(yytext, "THEN")) { return (THEN); }  
    if (isKW(yytext, "WHILE")) { return (WHILE); }  
    if (isKW(yytext, "CASE")) { return (CASE); }  
    if (isKW(yytext, "ESAC")) { return (ESAC); }  
    if (isKW(yytext, "OF")) { return (OF); }  
    if (isKW(yytext, "NEW")) { return (NEW); }  
    if (isKW(yytext, "ISVOID")) { return (ISVOID); }  
    if (isKW(yytext, "NOT")) { return (NOT); }  
    // BOOLEAN:
    if (isKW(yytext, "TRUE")) { cool_yylval.boolean = 1; return (BOOL_CONST); }  
    if (isKW(yytext, "FALSE")) { cool_yylval.boolean = 0; return (BOOL_CONST); }  
    // IDS:
    if (isUP(yytext)) { cool_yylval.symbol = stringtable.add_string(yytext); return (TYPEID); }  
    else { cool_yylval.symbol = stringtable.add_string(yytext); return (OBJECTID); }
}

{DARROW} return (DARROW);
"<=" return (LE);

 /* 
  * Number:
  */
{DIGIT}+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}

%%

bool isKW(char* str1, char* str2) {
    if (strlen(str1) != strlen(str2)) {
        return false;
    }
    for (int i=strlen(str1)-1; i>=0; i--) {
        if (!(str1[i] == str2[i] || str1[i]-str2[i] == 32 || str1[i]-str2[i] == -32)) {
            return false;
        }
    }
    return true;
}

bool isUP(char* yytext) {
    return (yytext[0]<='Z'&&yytext[0]>='A');
}

void addChar2String(char *yytext) {
    int curlen = strlen(string_buf);
    int newlen = strlen(yytext);

    if (curlen+newlen > MAX_STR_CONST) {
        yylval.error_msg = "String constant too long";
        BEGIN(strerr);
    } else {
        string_buf_ptr = string_buf + curlen;
        strcpy(string_buf_ptr, yytext);
    }
}
