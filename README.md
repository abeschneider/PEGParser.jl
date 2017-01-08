[![Build Status](https://travis-ci.org/abeschneider/PEGParser.jl.svg?branch=master)](https://travis-ci.org/abeschneider/PEGParser.jl)

# PEGParser

PEGParser is a parsing library for Parsing Expression Grammars (PEG) in Julia. It was inspired by pyparsing, parsimonious, boost::spirit, as well as several others. The original design was set up by Abe Schneider in 2014. As of January 2017 Henry Schurkus has reworked major parts of the library design. With the redesign also came a change of the API for easier and less error prone use. Below we describe the new design which takes grammar declarations in the form of (multiline) strings. The previous design relied heavily on the specific parsing logic of the julia language and should therefore be considered deprecated.

# Super Quick Tutorial For The Very Busy
A parser takes a string and a grammar specification to turn the former into a computable structure. PEGParser does this by first parsing (`parse(grammar,string)`) the string into an Abstract Syntax Tree (AST) and then transforming this AST into the required structure (`transform(function,AST`).

## Defining a grammar

A grammar can be defined as:

```julia
Grammar("""
  rule1 = ...
  rule2 = ...
  ...
""")
```

where the following rules can be used:

* References to other rules: `theotherrule`
* Terminals: `'a'` (must match literally)
* Or: `rule1 | rule2 | rule3` (the first rule that matches wins)
* And: `rule1 & rule2 & rule3` (the rules are matched one after the other (`&` groups stronger than `|`)
* Grouping: `(rule1 + rule2) | (rule3 + rule4)`
* Optional: `?(rule1)` (is matched if possible, but counts as matched anyways)
* One or more: `+(rule1)` (is matched as often as possible, but has to be matched at least once)
* Zero or more: `*(rule1)` (is matched as often as possible, but counts as matched even if never matched)
* Regular expressions: `r([a-zA-Z]+)r` (matches whatever the regex between r( and )r matches)
* Suppression: `-(rule1)` (the rule has to be matched but yields no node to the AST)
* Semantic action: `rule{ expr }` (uses expr to create the node instead of the default `no_action`; see below for more)

The argument to `Grammar()` is a String, where line ends or semicoli (;) can be used to separate rules.
All grammars by default use `start` as the starting rule. You can specify a different starting rule in the `parse` function if you desire.

### Example 1
Note: All these examples and more can be found in the examples folder of PEGParser.

Let's start by creating a simple calculator that can take two numbers and an operator to give a result.

We first define the grammar:
```julia
calc1 = Grammar("""
  start => (number & op & number)

  op => plus | minus
  number => (-(space) & r([0-9]+)r) 
  plus => (-(space) & '+')
  minus => (-(space) & '-')
  space => r([ \\t\\n\\r]*)r
""")
```

The starting rule is composed of two other rules: `number` and `op`. For this calculator, we only allow `+` and `-`. 

The `number` rule just matches any digit between 0 to 9. You'll note that spaces appear in front of all terminals. This is because PEGs don't handle spaces automatically.

## Parsing
`parse(grammar,string)` allows the construction of the AST of `string` according to `grammar`.

### Example 1 continued
Now we can run this grammar with some input:

```julia
(ast, pos, error) = parse(calc1, "4+5")
println(ast)
```

resulting in the following output:

```
node() {PEGParser.AndRule}
1: node() {PEGParser.AndRule}
  1: node() {'4',PEGParser.RegexRule}
2: node() {PEGParser.AndRule}
  1: node() {'+',PEGParser.Terminal}
3: node() {PEGParser.AndRule}
  1: node() {'5',PEGParser.RegexRule}
```

## Transformation

Finally one transforms the AST to the desired datastructure by first defining an accordingly overloaded actuator function and then calling it recursively on the AST by `transform(function, ast)`.

### Example 1 continued
We now have the desired AST for "4+5". For our calculator we do not want to put everything into a datastructure, but actually fold it all up directly into the final result.

For the transformation an actuator function needs to be defined, which specifies on the name of the nodes. So we first need to give names to the parsed nodes:

```julia
calc1 = Grammar("""
  start => (number & op & number) {"start"}

  op => (plus | minus) {"op"}
  number => (-(space) & r([0-9]+)r) {"number"}
  plus => (-(space) & '+') {"plus"}
  minus => (-(space) & '-') {"minus"}
  space => r([ \\t\\n\\r]*)r 
""")
```
leading to the following AST
```julia
node(start) {PEGParser.AndRule}
1: node(number) {PEGParser.AndRule}
  1: node() {'4',PEGParser.RegexRule}
2: node(plus) {PEGParser.AndRule}
  1: node() {'+',PEGParser.Terminal}
3: node(number) {PEGParser.AndRule}
  1: node() {'5',PEGParser.RegexRule}
```

We can now define the actuator function as
```julia
toresult(node,children,::MatchRule{:default}) = node.value
toresult(node,children,::MatchRule{:number}) = parse(Int,node.value)
toresult(node,children,::MatchRule{:plus}) = +
toresult(node,children,::MatchRule{:minus}) = -
toresult(node,children,::MatchRule{:start}) = children[2](children[1],children[3])
```
and recursively apply it to our AST
```julia
transform(toresult,ast)
```
to obtain the correct result, `9`.

## Actions

Not always does one want to create every node directly as a basic `Node` type. Actions allow to directly act on parts of the AST during its very construction. An action is specified by `{ action }` following any rule. Generally a function (anonymous or explicit) has to be specified which takes the following arguments `(rule, value, firstpos, lastpos, childnodes)` and may return anything which nodes higher up in the AST can work with. 

As a shorthand just specifying a name as a string, e.g. "name", results in a normal node, but with the specified name set. This is how we did the naming in example 1 above. As a side note: The action `liftchild` just takes the child of the node and returns in on the current level. This is the default action for `|`-rules - whichever child gets matched gets returned at the place of the or rule as if we had explicitly specified
```julia
myOrRule = (rule1 | rule2) {liftchild}
```

### Where do actions apply?
Actions always apply to the single token preceding them, so in
* `rule1 {action} & rule2` `action` applies to rule1
* `rule1 & rule2 {action}` `action` applies to rule2
* `(rule1 & rule2) {action}` `action` applies to the `&`-rule joining rule1 and rule2.
For another example, in
* `*(rule) {action}` `action` applies to the `*`-rule
* `*(rule {action})` `action` applies to `rule`.

### Example 2
As our calculator is really very simple we could have - instead of first building a named AST and then transforming it - directly parsed the string into the final result by means of actions:
```julia
calc2 = Grammar("""
  start => (number & op & number){(r,v,f,l,c) -> c[2](c[1],c[3])}

  op => plus | minus
  number => (-(space) & r([0-9]+)r) {(r,v,f,l,c) -> parse(Int,c[1].value)}
  plus => (-(space) & '+'){(a...) -> +}
  minus => (-(space) & '-'){(a...) -> -}
  space => r([ \\t\\n\\r]*)r
""")
```
which would have directly resulted in `9` when parsing `parse(calc2, "4+5")`.

### Example 3
Actually, the best example for how to parse stuff can be found in the source code itself. In `grammarparsing.jl` we give the grammar used to parse grammar specifications by the user. While it not actually live code, its consistency with what really happens is ensured by having it be a test in the test suite. Look here if you ever wonder about any specifics of grammar specification.

# An In Depth Guide To The Library

* The entry point to the library is of course the file `PEGParser.jl` which handles all `import`/`export`ing and includes the other files in order.
* `rules.jl` defines `Rule` and all its `subtypes`. These are typically consistent of a `name` (which by default constructor is simply ""), a type-specific `value` and an `action`.
* `grammar.jl` defines the `Grammar`-type as a dictionary mapping symbols to rules.
* `comparison.jl` defines comparison functions so that it is possible to check for example if two grammars are the same.
* `standardactions.jl` defines some utility actions which are often needed, e.g. the above mentioned `liftchild`.

*after these files are read it is now possible to specify any grammar in the most julia-nique way: By manually stacking constructors into one another.*

* `node.jl` defines the `Node`-type which makes up any AST. An AST is actually just a top-level node and all its (recursive) children.
* `parse.jl` defines the generic `parse` function and its children `parse_newcachekey` which are specified for each Rule subtype to handle the recursive parsing of a string by a specified grammar.
* `transform.jl` defines the `transform` function mentioned above.

*after these files are additionally read it is now possible to also parse and transform a string to a datastructure according to some grammar build by the manual stacking process discussed above*

* Since now all functionality is in principle available, `grammarparsing.jl` defines a grammar to parse grammars by the stacking process to allow the end-user to simply specify his or her grammar as a string.

Note, that some grammar functionality is still only available by direct construction as a consistent definition of such a grammargrammar becomes exponentially more difficult with the number of grammar features.

* `standardrules.jl` defines a grammar `standardrules` consisting only of commonly used rules like "space", "float", etc. so that they do not have to be defined by the end user every single time. Instead, the end user can simply join these rules into his or her definition by constructing the grammar as `Grammar("...", standardrules)`
