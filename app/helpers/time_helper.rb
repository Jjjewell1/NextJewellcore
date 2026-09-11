module TimeHelper
  def format_date(date)
    return "—" unless date
    date.strftime("%b %d, %Y")
  end

  def format_datetime(datetime)
    return "—" unless datetime
    datetime.strftime("%b %d, %Y at %H:%M %Z")
  end
end