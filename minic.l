%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "minic.tab.h"
void yyerror(const char *s);
%}

%%

"print"     {return PRINT;}  /* ADDED: Print Keyword */
"int"       {return INT;}
"if"        {return IF;}
"else"      {return ELSE;}
"for"       {return FOR;}
"while"     {return WHILE;}
"do"        {return DO;}
"switch"    {return SWITCH;}
"case"      {return CASE;}
"default"   {return DEFAULT;}
"break"     {return BREAK;}

[0-9]+      { yylval.iValue = atoi(yytext); return NUM; }
[a-zA-Z_][a-zA-Z0-9]* { yylval.sIndex = strdup(yytext); return ID; }

"#"         {return HASH;}

"+"         {return '+';}
"-"         {return '-';}
"*"         {return '*';}
"/"         {return '/';}
"++"        {return INC;}
"--"        {return DEC;}
"="         {return ASSIGN;}
"<"         {return '<';}
">"         {return '>';}
">="        {return GTE;}
"<="        {return LTE;}
"=="        {return EQ;}
"!="        {return NEQ;}
"["         {return LBK;}
"]"         {return RBK;}
"{"         {return LB;}
"}"         {return RB;}
"("         {return LP;}
")"         {return RP;}
":"         {return ':';}

[ \t\n]+    { /* Ignore whitespace */ }
.           { printf("Unknown character: %s\n", yytext); }

%%

int yywrap() { return 1; }