# PEGParser


PEGParser is a PEG Parser for Julia with Packrat capabilties. PEGParser was inspired by pyparsing, parsimonious, boost::spirit, as well as several others.
## Defining a grammar

To define a grammar you can write:

```julia
@grammar <name> begin
  rule1 = ...
  rule2 = ...
  ...
end
```

### Allowed rules

The following rules can be used:
* Terminals: Strings and characters
* Or: `a | b | c`
* And: `a + b + c`
* Grouping: `(a + b) | (c + d)`
* Optional: ?(a + b)
* One or more: `+((a + b) | (c + d))`
* Zero or more: `*((a + b) | (c + d))`
* Regular expressions: `r"[a-zA-Z]+"`
* Lists: `list(rule, delim)` *or* `list(rule, delim, min=1)`
* Suppression: `-rule`
* Semantic action: `rule { expr }`

For semantic actions, the `expr` may use the variables: `node`, `value`, `first`, `last`, and `children`. The `value` variable has a corresponding alias `_0` and each element of `children` `_i`, where `i` is the index into `children`. See below for examples using this.

#### TODO
Multiple: `(a+b)^(3, 5)`

## Example 1
Let's start by creating a simple calculator that can take two numbers and an operator to give a result.

We first define the grammar:
```julia
@grammar calc1 begin
  start = number + op + number
  op = plus | minus
  number = -space + r"[0-9]+"
  plus = -space + "+"
  minus = -space + "-"
  space = r"[ \t\n\r]*"
end
```

All grammars by default use `start` as the starting rule. You can specify a different starting rule in the `parse` function if you desire.

The starting rule is composed of two other rules: `number` and `op`. For this calculator, we only allow `+` and `-`. Note, that this could in fact be written more concisely with:

```julia
op = -space + r"[+-]"
```

The `number` rule just matches any digit between 0 to 9. You'll note that spaces appear in front of all terminals. This is because PEGs don't handle spaces automatically.

Now we can run this grammar with some input:

```julia
(ast, pos, error) = parse(calc1, "4+5")
println(ast)
```

will result in the following output:

```
node(start) {AndRule}
1: node(number) {AndRule}
  1: node(number.2) {'4',RegexRule}
2: node(plus) {AndRule}
  1: node(plus.2) {'+',Terminal}
3: node(number) {AndRule}
  1: node(number.2) {'5',RegexRule}
```

Our input is correctly parsed by our input, but we either have to traverse the tree to get out the result, or use change the output of the parse.

We can change the output of the parse with semantic actions. Every rule already has a semantic action attached to it. Normally it is set to either return a node in the tree or (for the or-rule) give the first child node.

For example, we can change the `number` rule to emit an actual number:

```julia
number = (-space + r"[0-9]+") { parseint(_1.value) }
```

The curly-braces after a rule allows either an expression or function to be used as the new action. In this case, the first child (the number, as the space is suppressed), as specified by `_1`, is parsed as an integer.

If we rewrite the grammar fully with actions defined for the rules, we end up with:

```julia
@grammar calc1 begin
  start = (number + op + number) {
    apply(eval(_2), _1, _3)
  }

  op = plus | minus
  number = (-space + r"[0-9]+") {parseint(_1.value)}
  plus = (-space + "+") {symbol(_1.value)}
  minus = (-space + "-") {symbol(_1.value)}
  space = r"[ \t\n\r]*"
end

data = "4+5"
(ast, pos, error) = parse(calc1, data)
println(ast)
```

We now get `9` as an answer. Thus, the parse is also doing the calculation. The code for this can be found in `calc1.jl`, with `calc2.jl` providing a more realistic (and useful) calculator.

In `calc3.jl`, you can find a different approach to this problem. Instead of trying to calculate the answer immediately, the full syntax tree is created. This allows it to be transformed into different forms. In this example, we transform the tree into Julia code:

```julia
@grammar calc3 begin
  start = expr

  expr_op = term + op1 + expr
  expr = expr_op | term
  term_op = factor + op2 + term

  term = term_op | factor
  factor = number | pfactor
  pfactor = (lparen + expr + rparen) { _2 }
  op1 = add | sub
  op2 = mult | div

  number = (-space + r"[1-9][0-9]*") { parseint(_1.value) }
  add = (-space + "+") { symbol(_1.value) }
  sub = (-space + "-") { symbol(_1.value) }
  mult = (-space + "*") { symbol(_1.value) }
  div = (-space + "/") { symbol(_1.value) }

  lparen = (-space + "(") { _1 }
  rparen = (-space + ")") { _1 }
  space = r"[ \n\r\t]*"
end
```

provides the grammar, and then we define the transforms:

```julia
toexpr(node, cnodes, ::MatchRule{:default}) = cnodes
toexpr(node, cnodes, ::MatchRule{:term_op}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:expr_op}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
```

which when applied to the parse tree, results in a Julia AST:

```julia
(ast, pos, error) = parse(calc3, "4+5*(8+2)")
code = transform(toexpr, ast)
```


## Caveats

This is still very much a work in progress and doesn't yet have as much test coverage as I would like.

The error handling still needs a lot of work. Currently only a single error will be emitted, but the hope is to allow multiple errors to be returned.
