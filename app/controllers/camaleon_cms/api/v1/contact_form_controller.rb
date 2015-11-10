class Api::V1::ContactFormController < CamaleonCms::Api::ApiController
  #TODO this controller must be into ContactForm plugin app
  skip_before_filter :verify_authenticity_token

  swagger_controller :contact_form, 'ContactForm'

  swagger_api :contact_form_by_slug do
    summary "Fetch a single Contact Form by slug"
    param :path, :slug, :string, :required, 'Contact form slug'
    response :ok, 'Success', :ContactForm
    response :not_found
  end

  def contact_form_by_slug
    form = current_site.contact_forms.where("parent_id is null and slug = '#{params[:slug]}'").first
    if form.nil?
      render_json_not_found
    else
      render json: {
                 :id => form.id,
                 :fields => JSON.parse(form.value).to_sym[:fields],
                 :settings => JSON.parse(form.settings).to_sym
             }
    end
  end

  swagger_api :save_form do
    summary "Submit a contact form"
    param :form, :id, :integer, :required, 'Contact form id'
    param :form, :fields, :array, :required, 'Fields'
    response :ok, 'Success'
    response :not_found
  end

  def save_form
    form = current_site.contact_forms.find_by_id(params[:id])
    unless form.nil?
      values = JSON.parse(form.value).to_sym
      settings = JSON.parse(form.settings).to_sym
      fields = params[:fields]
      errors = []
      success = []

      perform_save_form(form, values, fields, settings, success, errors)
      if success.present?
        render_json_ok(success.join('<br>'))
      else
        render_json_ok({:errors => :errors, :fields => fields})
      end
    else
      render_json_not_found
    end
  end

end
