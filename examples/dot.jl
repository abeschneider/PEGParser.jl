using EBNF
using PEGParser

type GraphNode
  name
end

type GraphEdge
  from
  to
end

# @grammar dot begin
#   start = graph
# #   graph = (graph_label | digraph_label) + lbrace + stmt_list + rbrace
#   graph = graph_label + lbrace + stmt_list + rbrace
#   stmt_list = list(id, semicolon)
#   stmt = (edge_stmt | node_stmt | assignment) #+ (manditory_space | semicolon)
#   edge_stmt = node_id + edgeop + node_id
#   node_stmt = node_id
#   node_id = id
#   assignment = id + equals + id

#   graph_label = "graph" + space
#   digraph_label = "digraph" + space
#   lbrace = "{" + space
#   rbrace = "}" + space
#   equals = "=" + space
#   edgeop = "->" + space
#   semicolon = ";" + space
#   id = r"[a-zA-z][a-zA-Z0-9]*" + space
#   space = r"[ \t\n]*"
#   manditory_space = r"[ \t\n]+"
# #   stmt = (node_stmt | edge_stmt | attr_stmt | assignment | subgraph) + ?(";")
# #   attr_stmt = (graph | node | edge)
# #   assignment_list = assignment *((";" | ",") + assignment)

# #   edge_stmt = (node_id | subgraph) + edgeRHS
# #   edgeRHS = edgeop + (node_id | subgraph)
# #   node_stmt = node_id
# #   node_id = id
# #   port = (":" + id) | (":" + compass_pt)
# #   subgraph = "{" + stmt_list + "}"
# #   compass_pt = "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "nw" | "c" | "_"
# #   edgeop = "->" | "--"
# end

@grammar test begin
  start = graph_label + lbrace + stmt_lst + rbrace
  stmt_lst = *(stmt + ?(semicolon))
  stmt = edge_stmt | node_stmt
  node_stmt = node_id
  edge_stmt = node_id + edgeop + node_id
  node_id = r"[a-zA-Z][a-zA-Z0-9]*" + space

  graph_label = "graph" + space
  semicolon = ";" + space
  lbrace = "{" + space
  rbrace = "}" + space
  edgeop = "->" + space
  space = r"[ \t\n\r]*"
end

foobar(node::Node, cvalues, ::MatchRule{:default}) = cvalues
foobar(node::Node, cvalues, ::MatchRule{:start}) = cvalues
foobar(node::Node, cvalues, ::MatchRule{:stmt_lst}) = cvalues
foobar(node::Node, cvalues, ::MatchRule{:stmt}) = cvalues
foobar(node::Node, cvalues, ::MatchRule{:node_stmt}) = GraphNode(cvalues)
foobar(node::Node, cvalues, ::MatchRule{:edge_stmt}) = GraphEdge(cvalues[1], cvalues[2])
foobar(node::Node, cvalues, ::MatchRule{:node_id}) = cvalues

parse_data = """
graph {this;is}
"""


println("parsing...")
(ast, pos, error) = parse(test, parse_data)
println("$ast")
println(error)
println("transforming...")
result = transform(foobar, ast, ignore=[:space, :manditory_space, :semicolon, :edgeop, :equals, :lbrace, :rbrace, :graph_label, :digraph_label])

println(result)
