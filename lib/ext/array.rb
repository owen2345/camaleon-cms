class Array
  # delete empty values
  def clean_empty
    delete_if(&:blank?)
    self
  end

  # add default value if array is empty
  def fix_in_sql(def_val = -1)
    self << def_val if empty?
    self
  end

  def delete_item(item)
    delete_if { |a| a.to_s == item.to_s }
  end

  # remove all item from array
  def delete_items(items)
    items = items.to_s_
    delete_if { |a| items.include?(a.to_s) }
  end

  def to_i
    collect(&:to_i)
  end

  def strip
    collect { |i| i.to_s.strip }
  end

  # convert all items to string
  def to_s_
    collect(&:to_s)
  end

  # delete last item
  def delete_last
    slice(0, size - 1)
  end

  # join pluck arrays
  def join_pluck
    collect { |row| row[1].present? ? row.join(',') : row[0] }.join(',').to_s.split(',')
  end

  def join_bar
    uniq.map { |us_id| "__#{us_id}__" }.join(',')
  end

  # alternative pluck method for arrays
  def cama_pluck(attribute)
    map { |i| i.send(attribute) }
  end
end
