module ApplicationHelper
  def time_ago(time)
    return "unknown" unless time
    distance_of_time_in_words_to_now(time)
  end

  def source_initial(name)
    name.first(2).upcase
  end
end