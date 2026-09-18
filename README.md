# Mini-C Interactive Interpreter

A small interactive interpreter for a C-like scripting language, built with **Flex** (lexer) and **Bison** (parser). Statements are executed immediately as they're entered — there's no separate compile step.

## Language Notes

This isn't standard C syntax — a few things are different:

- Statements end with `#` instead of `;`.
- Parentheses `()`, brackets `[]`, and braces `{}` are all interchangeable for grouping a single expression; `{}` also delimits statement blocks.
- Declarations look like `int x#` or `int x = 5#`.

## Features

- Variable declarations and assignment (`int x = 5#`)
- Arithmetic (`+ - * /`) and comparison (`< > <= >= == !=`) operators
- `print` statement
- `++` / `--` increment/decrement
- `if` / `else`
- `while` and `do...while` loops
- `for` loops — both `for (i = 0# i < 3# i++)` (pre-declared variable) and `for (int i = 0# i < 3# i++)` (inline declaration)
- `switch` / `case` / `default` with `break`

## How to Build

Requires `flex`, `bison`, and `gcc`.

```bash
bison -d minic.y -o minic.tab.c
flex -o lex.yy.c minic.l
gcc -o minic minic.tab.c lex.yy.c -lfl
```

## How to Run

```bash
./minic
```

It starts an interactive prompt (`>`) and executes each statement as you type it. You can also pipe in a script:

```bash
./minic < myscript.txt
```

## Example

```
int x = 0#
for (int i = 0# i < 5# i++) {
    x = x + i#
    print x#
}#

int y = 10#
switch (y) {
case 10: print 100# break#
default: print 0#
}#
```

## Known Limitations

- No functions, arrays, or string types — only integers.
- `freeNode()` is a no-op, so memory used by parse-tree nodes is never freed (fine for short interactive sessions, not for long-running scripts).
- Error recovery is minimal — a syntax error prints a message but doesn't attempt to resynchronize cleanly.

## License

This project is open source — feel free to use or modify it.
