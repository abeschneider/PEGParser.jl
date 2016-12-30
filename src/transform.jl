# default transform is to do nothing
transform{T}(fn::Function, value::T) = value

function transform(fn::Function, node::Node)
  if isa(node.children, Array)
    transformed = [transform(fn, child) for child in node.children]
  else
    transformed = transform(fn, node.children)
  end

  if method_exists(fn, (Node, Any, MatchRule{node.sym}))
    label = MatchRule{node.sym}()
  else
    label = MatchRule{:default}()
  end

  return fn(node, transformed, label)
end
