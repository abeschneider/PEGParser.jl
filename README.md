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
* Selection rule: `rule[fn]`

#### TODO
Multiple: `(a+b)^(3, 5)`

## Example 1
Suppose you want a parser that takes input and converts `[text]` into `<b>text<>`. You can write the following grammar:

```julia
@grammar markup begin
  # this is the standard start rule
  start = bold_text

  # compose a sequence
  bold_text = bold_open + text + bold_code

  # use a regular expression to define the text
  text = r"[a-zA-z]*"

  bold_open = '['
  bold_close = ']'
end
```

The first step in using the grammar is to create an AST from a given input:

```julia
(ast, pos, error) = parse(markup, "[test]")
```

The variable `ast` contains the AST which can be transformed to the desired result. To do so, first a mapping of the node names to transform has to established:

```julia
tohtml(node, cvalues, ::MatchRule{:bold_open}) = "<b>"
tohtml(node, cvalues, ::MatchRule{:bold_close}) = "</b>"
tohtml(node, cvalues, ::MatchRule{:text}) = node.value
tohtml(node, cvalues, ::MatchRule{:bold_text}) = join(cvalues)

```

And finally:
```julia
result = transform(tohtml, ast)
println(result) # "<b>test</b>"
```

## Example 2
Transforms can also be used to calculate a value from the tree. Consider the standard calculator app:

```julia
@grammar calcgrammar begin
  start = (expr)[(ast) -> ast.children[1]]

  exprop = term + op1 + expr
  expr = (exprop | term)[(ast) -> ast.children[1]]
  termop = factor + op2 + term
  term = (termop | factor)[(ast) -> ast.children[1]]
  factor = (number | pfactor)[(ast) -> ast.children[1]]
  pfactor = (-lparen + expr + -rparen)[(ast) -> ast.children[1]]

  op1 = (add | sub)[1]
  op2 = (mult | div)[1]

  number = (-space + r"[1-9][0-9]*")[1]
  add = (-space + "+")[1]
  sub = (-space + "-")[1]
  mult = (-space + "*")[1]
  div = (-space + "/")[1]
  lparen = space + "("
  rparen = space + ")"
  space = r"[ \n\r\t]*"
end
```

You will notice that some rules end in `[...]`, which is called a selection rule. This allows a user-defined function to be invoked whenever the given rule matches, which can be useful during the transform phase. The user-defined function takes the form of: `(node) -> node`. Two common use-cases of this are:

* **or**: Given the rule `a|b|c`, the resulting match for `a` will be: `rule -> or-rule -> a`. In this case, the `or-rule` doesn't add information, and instead `rule -> a` is preferable. The function:
```julia
(node) -> Node(node.name, node.children[i].value, node.children[i].first, ndoe.children[i].last, node.children[i].children, node.children[i].ruleType)
```
will remove the extraneous `or-rule`. This can be simplified as `rule[i]`.
* **and**: Given the rule `-lparen + rule2 + -rparen`, the resulting match of `rule2` will be: `rule -> and-rule -> rule2`. While both `lparen` and `rparen` are suppressed, `rule2` is still a child of the `and-rule`. The selection rule for `rule` can be given as:
```julia
(node) -> node.children[1]
```


To use the grammar to generate a Julia expression:

```julia
(node, pos, error) = parse(grammar, "5*(42+3+6+10+2)")

toexpr(node, cnodes, ::MatchRule{:default}) = cnodes
toexpr(node, cnodes, ::MatchRule{:termop}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:exprop}) = Expr(:call, cnodes[2], cnodes[1], cnodes[3])
toexpr(node, cnodes, ::MatchRule{:number}) = parseint(node.value)
toexpr(node, cnodes, ::MatchRule{:op1}) = symbol(node.value)
toexpr(node, cnodes, ::MatchRule{:op2}) = symbol(node.value)

result = transform(toexpr, node)

println(result) # 315.0
```

## Caveats

This is still very much a work in progress and doesn't yet have as much test coverage as I would like.

The error handling still needs a lot of work. Currently only a single error will be emitted, but the hope is to allow multiple errors to be returned.
