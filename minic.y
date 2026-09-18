%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

int yylex(void);
void yyerror(const char *s);
%}

/* --- DATA STRUCTURES --- */
%code requires {
    typedef enum { typeCon, typeId, typeOpr } nodeEnum;

    typedef struct { int value; } conNodeType;
    typedef struct { char *name; } idNodeType;
    typedef struct { int oper; int nops; struct nodeTypeTag *op[4]; } oprNodeType;

    typedef struct nodeTypeTag {
        nodeEnum type;
        union { conNodeType con; idNodeType id; oprNodeType opr; };
    } nodeType;

    nodeType *con(int value);
    nodeType *id(char *name);
    nodeType *opr(int oper, int nops, ...);
    void freeNode(nodeType *p);
    int ex(nodeType *p);
}

%union {
    int iValue;                 
    char *sIndex;               
    nodeType *nPtr;             
};

%token <iValue> NUM
%token <sIndex> ID
%token PRINT INT FOR WHILE DO IF SWITCH CASE DEFAULT BREAK
%token INC DEC HASH
%token LP RP LB RB LBK RBK

/* --- PRECEDENCE --- */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%right ASSIGN
%left '<' '>' GTE LTE EQ NEQ
%left '*' '/'   
%left '+' '-'   
%left INC DEC

%type <nPtr> st sts Expr_Stmt Control_Flow_st
%type <nPtr> IF_ST LOOP_ST FOR_LOOP WHILE_LOOP DO_WHILE_LOOP BLOCK
%type <nPtr> EXP Declaration_st SWITCH_ST Case_List Case_Item

%%

/* --- GRAMMAR --- */

program:
    /* Empty rule allows starting execution immediately */
    | program st { 
        ex($2);       /* Execute the statement IMMEDIATELY */
        freeNode($2); /* Free memory */
        printf("> "); /* Print a prompt for the next line */
    }
;

/* sts is still needed for BLOCKS { ... } inside loops/if */
sts:
    sts st          { $$ = opr(5, 2, $1, $2); } 
    | st            { $$ = $1; }
;

st:
      Declaration_st
    | Expr_Stmt
    | Control_Flow_st
    | BLOCK
    | HASH          { $$ = opr(5, 0); } 
;

Declaration_st:
      INT ID HASH               { $$ = opr(6, 2, id($2), con(0)); } 
    | INT ID ASSIGN EXP HASH    { $$ = opr(6, 2, id($2), $4); }
;

Expr_Stmt:
      PRINT EXP HASH            { $$ = opr(1, 1, $2); }
    | EXP HASH                  { $$ = $1; } 
;

EXP:
      NUM                       { $$ = con($1); }
    | ID                        { $$ = id($1); }
    /* Moved INC/DEC here so they work inside FOR loops */
    | ID INC                    { $$ = opr(6, 2, id($1), opr('+', 2, id($1), con(1))); }
    | ID DEC                    { $$ = opr(6, 2, id($1), opr('-', 2, id($1), con(1))); }
    | ID ASSIGN EXP             { $$ = opr(6, 2, id($1), $3); }
    | EXP '+' EXP               { $$ = opr('+', 2, $1, $3); }
    | EXP '-' EXP               { $$ = opr('-', 2, $1, $3); }
    | EXP '*' EXP               { $$ = opr('*', 2, $1, $3); }
    | EXP '/' EXP               { $$ = opr('/', 2, $1, $3); }
    | EXP '<' EXP               { $$ = opr('<', 2, $1, $3); }
    | EXP '>' EXP               { $$ = opr('>', 2, $1, $3); }
    | EXP GTE EXP               { $$ = opr(GTE, 2, $1, $3); }
    | EXP LTE EXP               { $$ = opr(LTE, 2, $1, $3); }
    | EXP EQ EXP                { $$ = opr(EQ, 2, $1, $3); }
    | EXP NEQ EXP               { $$ = opr(NEQ, 2, $1, $3); }
    | LBK EXP RBK               { $$ = $2; }
    | LB EXP RB                 { $$ = $2; }
    | LP EXP RP                 { $$ = $2; }
;

Control_Flow_st:
      IF_ST
    | LOOP_ST
    | SWITCH_ST
;

IF_ST:
      IF LP EXP RP st %prec LOWER_THAN_ELSE  { $$ = opr(2, 2, $3, $5); } 
    | IF LP EXP RP st ELSE st                { $$ = opr(2, 3, $3, $5, $7); }
;

LOOP_ST:
      FOR_LOOP
    | WHILE_LOOP
    | DO_WHILE_LOOP
;

FOR_LOOP:
    FOR LP EXP HASH EXP HASH EXP RP st 
    { $$ = opr(4, 4, $3, $5, $7, $9); }
    | FOR LP Declaration_st EXP HASH EXP RP st
    { $$ = opr(4, 4, $3, $4, $6, $8); }
;

WHILE_LOOP:
    WHILE LP EXP RP st 
    { $$ = opr(3, 2, $3, $5); } 
;

DO_WHILE_LOOP:
    DO st WHILE LP EXP RP HASH
    { $$ = opr(7, 2, $2, $5); } 
;

SWITCH_ST:
    SWITCH LP EXP RP LB Case_List RB
    { $$ = opr(8, 2, $3, $6); } 
;

Case_List:
    Case_List Case_Item { $$ = opr(5, 2, $1, $2); }
    | Case_Item         { $$ = $1; }
;

Case_Item:
      CASE NUM ':' sts BREAK HASH    { $$ = opr(9, 2, con($2), $4); } 
    | DEFAULT ':' sts                { $$ = opr(9, 2, con(-999), $3); } 
;

BLOCK:
    LB sts RB { $$ = $2; }
    | LB RB   { $$ = opr(5, 0); }
;

%%

/* --- INTERPRETER ENGINE --- */

#define OPR_PRINT 1
#define OPR_IF    2
#define OPR_WHILE 3
#define OPR_FOR   4
#define OPR_SEQ   5
#define OPR_ASGN  6
#define OPR_DO    7
#define OPR_SW    8
#define OPR_CASE  9

struct Symbol {
    char *name;
    int val;
} sym[100];
int sym_cnt = 0;

nodeType *con(int value) {
    nodeType *p = malloc(sizeof(nodeType));
    p->type = typeCon;
    p->con.value = value;
    return p;
}

nodeType *id(char *name) {
    nodeType *p = malloc(sizeof(nodeType));
    p->type = typeId;
    p->id.name = strdup(name);
    return p;
}

nodeType *opr(int oper, int nops, ...) {
    va_list ap;
    nodeType *p = malloc(sizeof(nodeType));
    p->type = typeOpr;
    p->opr.oper = oper;
    p->opr.nops = nops;
    va_start(ap, nops);
    for (int i = 0; i < nops; i++)
        p->opr.op[i] = va_arg(ap, nodeType*);
    va_end(ap);
    return p;
}

int get_val(char *name) {
    for(int i=0; i<sym_cnt; i++) {
        if(strcmp(sym[i].name, name) == 0) return sym[i].val;
    }
    return 0; 
}

void update_val(char *name, int val) {
    for(int i=0; i<sym_cnt; i++) {
        if(strcmp(sym[i].name, name) == 0) {
            sym[i].val = val;
            return;
        }
    }
    sym[sym_cnt].name = strdup(name);
    sym[sym_cnt].val = val;
    sym_cnt++;
}

/* Walks a Case_List tree looking for a case matching `val`.
   Returns 1 and executes the matching case's statements if found.
   If no case matches but a default case exists, *defaultStmts is set
   so the caller can run it. */
int exec_case(nodeType *p, int val, nodeType **defaultStmts) {
    if (!p) return 0;
    if (p->type == typeOpr && p->opr.oper == OPR_SEQ) {
        if (exec_case(p->opr.op[0], val, defaultStmts)) return 1;
        return exec_case(p->opr.op[1], val, defaultStmts);
    }
    if (p->type == typeOpr && p->opr.oper == OPR_CASE) {
        int caseVal = p->opr.op[0]->con.value;
        if (caseVal == -999) {
            *defaultStmts = p->opr.op[1];
            return 0;
        }
        if (caseVal == val) {
            ex(p->opr.op[1]);
            return 1;
        }
    }
    return 0;
}

int ex(nodeType *p) {
    if (!p) return 0;
    switch(p->type) {
        case typeCon: return p->con.value;
        case typeId:  return get_val(p->id.name);
        case typeOpr:
            switch(p->opr.oper) {
                case OPR_SEQ:
                    ex(p->opr.op[0]);
                    return ex(p->opr.op[1]);
                case OPR_PRINT:
                    {
                        int v = ex(p->opr.op[0]);
                        printf(">> Output: %d\n", v);
                        return v;
                    }
                case OPR_ASGN:
                    {
                        int v = ex(p->opr.op[1]);
                        update_val(p->opr.op[0]->id.name, v);
                        return v;
                    }
                case OPR_WHILE:
                    while(ex(p->opr.op[0])) ex(p->opr.op[1]);
                    return 0;
                case OPR_DO:
                    do { ex(p->opr.op[0]); } while(ex(p->opr.op[1]));
                    return 0;
                case OPR_FOR:
                    ex(p->opr.op[0]); 
                    while(ex(p->opr.op[1])) {
                        ex(p->opr.op[3]); 
                        ex(p->opr.op[2]); 
                    }
                    return 0;
                case OPR_IF:
                    if (ex(p->opr.op[0]))
                        ex(p->opr.op[1]);
                    else if (p->opr.nops > 2)
                        ex(p->opr.op[2]);
                    return 0;
                case OPR_SW:
                    {
                        int val = ex(p->opr.op[0]);
                        nodeType *defaultStmts = NULL;
                        if (!exec_case(p->opr.op[1], val, &defaultStmts) && defaultStmts)
                            ex(defaultStmts);
                        return 0;
                    }
                case '+': return ex(p->opr.op[0]) + ex(p->opr.op[1]);
                case '-': return ex(p->opr.op[0]) - ex(p->opr.op[1]);
                case '*': return ex(p->opr.op[0]) * ex(p->opr.op[1]);
                case '/': return ex(p->opr.op[0]) / ex(p->opr.op[1]);
                case '<': return ex(p->opr.op[0]) < ex(p->opr.op[1]);
                case '>': return ex(p->opr.op[0]) > ex(p->opr.op[1]);
                case GTE: return ex(p->opr.op[0]) >= ex(p->opr.op[1]);
                case LTE: return ex(p->opr.op[0]) <= ex(p->opr.op[1]);
                case EQ:  return ex(p->opr.op[0]) == ex(p->opr.op[1]);
                case NEQ: return ex(p->opr.op[0]) != ex(p->opr.op[1]);
            }
    }
    return 0;
}

void freeNode(nodeType *p) {}

void yyerror(const char *s) {
    printf("Syntax Error: %s\n", s);
}

int main() {
    printf("--- Interactive Compiler Ready ---\n");
    printf("> "); /* Initial Prompt */
    yyparse();
    return 0;
}