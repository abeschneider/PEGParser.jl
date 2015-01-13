using PEGParser

type GraphNode
  name
end

type GraphEdge
  from
  to
end

@grammar test begin
  start = graph_label + lbrace + stmt_lst + rbrace
  stmt_lst = *(stmt + ?(semicolon))
  stmt = edge_stmt | node_stmt
  node_stmt = node_id
  edge_stmt = node_id + edgeop + node_id

  node_id = node_id_value + space
  node_id_value = r"[a-zA-Z][a-zA-Z0-9]*"
  graph_label = "graph" + space
  semicolon = ";" + space
  lbrace = "{" + space
  rbrace = "}" + space
  edgeop = "->" + space
  space = r"[ \t\n\r]*"
end

tograph(node::Node, cvalues, ::MatchRule{:default}) = cvalues
tograph(node::Node, cvalues, ::MatchRule{:node_stmt}) = GraphNode(cvalues)
tograph(node::Node, cvalues, ::MatchRule{:edge_stmt}) = GraphEdge(cvalues[1], cvalues[2])
tograph(node::Node, cvalues, ::MatchRule{:node_id_value}) = node.value

parse_data = """
graph {
  nodeA
  nodeA -> nodeC
  nodeB -> nodeC
}
"""

(ast, pos, error) = parse(test, parse_data)
result = transform(tograph, ast, ignore=[:space, :manditory_space, :semicolon, :edgeop, :equals, :lbrace, :rbrace, :graph_label, :digraph_label])
println(result)
