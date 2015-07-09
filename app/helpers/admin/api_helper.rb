module Admin::ApiHelper
  def admin_api
    json = {error: 'Not Found Method'}
    case params[:method]
      when 'reorder'
        case params[:model]
          when 'field_groups'
            params[:values].to_a.each_with_index do |value, index|
              current_site.custom_field_groups.find(value).update_column('field_order', index)
            end
            json = {size: params[:values].size}
        end
    end




    json
  end

end