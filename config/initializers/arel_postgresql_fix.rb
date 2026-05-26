# Fix for AREL 3.0.3 with PostgreSQL - Cannot visit Integer in LIMIT clause
# This is a compatibility issue between old AREL and newer PostgreSQL adapters

if defined?(Arel::Visitors::PostgreSQL)
  module Arel
    module Visitors
      class PostgreSQL < ToSql
        private
        
        # Override to handle Integer LIMIT values properly
        def visit_Arel_Nodes_Limit(o, collector = nil)
          if collector
            collector << "LIMIT "
            visit o.expr, collector
          else
            "LIMIT #{o.expr.respond_to?(:to_i) ? o.expr.to_i : visit(o.expr)}"
          end
        end
        
        # Override to handle Integer OFFSET values properly  
        def visit_Arel_Nodes_Offset(o, collector = nil)
          if collector
            collector << "OFFSET "
            visit o.expr, collector
          else
            "OFFSET #{o.expr.respond_to?(:to_i) ? o.expr.to_i : visit(o.expr)}"
          end
        end
      end
    end
  end
end
