class Array
  # delete empty values
  def clean_empty
    self.delete_if {|v| v.blank? }
    self
  end

  # add default value if array is empty
  def fix_in_sql(def_val = -1)
    self << def_val if self.empty?
    self
  end

  def delete_item(item)
    self.delete_if { |a| a.to_s == item.to_s }
  end

  # remove all item from array
  def delete_items(items)
    items = items.to_s_
    self.delete_if { |a| items.include?(a.to_s) }
  end

  def to_i
    a = self.collect{|i| i.to_i}
    a
  end

  def strip
    a = self.collect{|i| i.to_s.strip}
    a
  end

  # convert all items to string
  def to_s_
    a = self.collect{|i| i.to_s}
    a
  end

  # delete last item
  def delete_last
    self.slice(0, self.size-1)
  end

  # join pluck arrays
  def join_pluck
    self.collect{|row| (row[1].present?)?row.join(","):row[0] }.join(",").to_s.split(",")
  end

  def join_bar
    self.uniq.map{|us_id| "__#{us_id}__"}.join(',')
  end

  # alternative pluck method for arrays
  def cama_pluck(attribute)
    self.map{|i| i.send(attribute) }
  end

end