# frozen_string_literal: true

require 'rails_helper'

# Regression: the confirm_email route declared `via: %i[get post path]` — `path` is not an HTTP verb
# (a typo for `patch`, the verb its `forgot`/`register` siblings accept), so a PATCH fell through to the
# admin catch-all "Invalid route" handler instead of reaching the action.
RSpec.describe 'Admin confirm_email routing', type: :routing do
  init_site

  %i[get post patch].each do |verb|
    it "routes #{verb.upcase} /admin/confirm_email to sessions#confirm_email" do
      expect(send(verb, '/admin/confirm_email')).to route_to('camaleon_cms/admin/sessions#confirm_email')
    end
  end
end
