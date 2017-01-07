type MatchRule{T} end

# default transform is to do nothing
transform{T}(fn::Function, value::T) = value

function transform(fn::Function, node::Node)
  if isa(node.children, Array)
    transformed = [transform(fn, child) for child in node.children]
  else
    transformed = transform(fn, node.children)
  end

  if method_exists(fn, (Node, Any, MatchRule{Symbol(node.name)}))
    label = MatchRule{Symbol(node.name)}()
  else
    label = MatchRule{:default}()
  end

  return fn(node, transformed, label)
end
