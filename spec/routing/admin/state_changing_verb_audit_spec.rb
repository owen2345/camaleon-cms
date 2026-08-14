# frozen_string_literal: true

require 'rails_helper'

# Security (audit M6): the admin-action-verb-safety capability requires that a state-changing admin
# endpoint is never reachable over a CSRF-exempt verb (GET/HEAD). The seven converted endpoints are
# pinned one-by-one in spec/requests/security/admin_destructive_get_verbs_spec.rb; this walks the
# loaded route set so the NEXT mutation-named admin route added anywhere in core is caught here
# instead of shipping a forgeable endpoint. Prose requirement:
# openspec/specs/admin-action-verb-safety/spec.md ("A new state-changing admin endpoint conforms").
RSpec.describe 'Security: admin state-changing routes are not GET-reachable (M6)', type: :routing do
  # Action-name fragments that denote a state change; a match makes the route suspect. The allowlist
  # below carves out the deliberate, documented exceptions.
  let(:mutating_action) do
    /destroy|delete|remove|trash|restore|toggle|upgrade|impersonate|create|update|save|import|
      load_data|crop|reset|clear|reorder|activate|deactivate|install|uninstall/x
  end

  # Deliberate GET-reachable exceptions, each documented:
  #   logout / back_to_parent -- render a confirmation on GET; the state change is POST-only (see the
  #     "Logout ends a session only over POST" requirement).
  #   crop -- M6 follow-up 2, converted later in this PR. REMOVE it from this list as the
  #     conversion lands.
  let(:allowed_get_actions) { %w[logout back_to_parent crop] }

  def admin_route?(route)
    route.defaults[:controller].to_s.start_with?('camaleon_cms/admin')
  end

  # An empty verb means the route matches every verb (via: :all) -- GET included.
  def get_or_head?(route)
    verb = route.verb.to_s
    verb.empty? || verb.match?(/GET|HEAD/)
  end

  def describe_route(route)
    verb = route.verb.to_s.presence || 'ANY'
    "#{verb} #{route.path.spec} => #{route.defaults[:controller]}##{route.defaults[:action]}"
  end

  it 'routes no mutation-named core admin action over GET or HEAD' do
    suspect = Rails.application.routes.routes.select do |route|
      action = route.defaults[:action].to_s
      admin_route?(route) && action.match?(mutating_action) &&
        !allowed_get_actions.include?(action) && get_or_head?(route)
    end
    offenders = suspect.map { |route| describe_route(route) }

    expect(offenders).to be_empty, <<~MSG
      State-changing admin routes reachable over GET/HEAD. Convert each to POST/PATCH (and update its
      callers), or -- if it is a deliberate GET-confirmation flow -- add its action to
      allowed_get_actions with a note:
      #{offenders.join("\n")}
    MSG
  end
end
