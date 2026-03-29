# CurrentRequest holds per-request state (user, site) accessible to models
# via ActiveSupport::CurrentAttributes (thread-safe, resets after each request).
#
# Usage in controllers:
#   CurrentRequest.user = cama_current_user
#   CurrentRequest.site = current_site
#
# Usage in models:
#   current_user  # delegates to CurrentRequest.user via CamaleonRecord
#   current_site  # delegates to CurrentRequest.site via CamaleonRecord
#
# Note: Rails automatically resets CurrentAttributes between requests, ensuring no leakage.
# In specs, call CurrentRequest.reset in before/after hooks to avoid cross-test pollution.
class CurrentRequest < ActiveSupport::CurrentAttributes
  attribute :user, :site
end
