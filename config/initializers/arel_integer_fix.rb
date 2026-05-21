# Ruby 2.4+ merged Fixnum/Bignum into Integer. Arel 3.0.3 only declares visit_* for Fixnum/Bignum,
# which breaks SQL generation / depth-first traversal for bare Integer literals (e.g. /my/page queries).

if defined?(Arel::Visitors::ToSql) && defined?(Arel::Visitors::DepthFirst)
  module Arel
    module Visitors
      class ToSql
        # Same dispatch as legacy visit_Fixnum (integer SQL fragments)
        alias :visit_Integer :literal
      end

      class DepthFirst
        private

        alias :visit_Integer :visit_Fixnum
      end
    end
  end
end
