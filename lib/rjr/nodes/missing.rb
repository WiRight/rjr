# RJR Missing Node Endpoint
#
# Provides a entity able to be associated with a rjr endpoint
# if the corresponding node cannot be loaded for whatever reason
#
# Copyright (C) 2012-2013 Mohammed Morsi <mo@morsi.org>
# Licensed under the Apache License, Version 2.0

require 'rjr/node'

module RJR
module Nodes
class Missing < RJR::Node
  def method_missing(method_id, *args, &bl)
    raise "rjr node #{node_id} is missing a dependency - cannot invoke #{method_id}"
  end
end
end
end
