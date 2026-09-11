module Pagination
  PAGE_SIZE = 20

  def self.apply(scope, page)
    page_num = [page.to_i, 1].max
    scope.offset((page_num - 1) * PAGE_SIZE).limit(PAGE_SIZE)
  end
end