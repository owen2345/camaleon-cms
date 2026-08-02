# frozen_string_literal: true

require 'rails_helper'

# Placement reads resolve `object_class` + `objectid` with no `parent_id` filter, so a group's
# owning site never enters the query. That is what makes a mis-stamped group render on a site that
# does not own it, and why the repair task re-homes such rows rather than the read path filtering
# them out -- see `design.md` D2 for why the read side is deliberately left alone.
#
# These expectations describe the mechanics the repair exists for, so they hold both before and
# after the write-side guard: the guard stops new violations, it does not change how reads resolve.
RSpec.describe CamaleonCms::CustomFieldGroup, type: :model do
  describe 'placement resolves without regard to the owning site' do
    let!(:owner_site) { create(:site) }
    let(:victim_site) { CamaleonCms::Site.create!(name: 'Victim', slug: 'victim-tenancy', taxonomy: 'site') }
    let(:victim_theme) { victim_site.get_theme }

    let!(:mis_stamped) do
      owner_site.custom_field_groups.create!(
        name: 'Mis-stamped', slug: '_mis-stamped', object_class: 'Theme', objectid: victim_theme.id
      )
    end

    it "renders on the victim site's theme settings" do
      expect(victim_theme.get_field_groups).to include(mis_stamped)
    end

    it "stays invisible in the victim site's own field group list" do
      expect(victim_site.custom_field_groups).not_to include(mis_stamped)
    end

    it "remains listed under the owning site, where the victim's administrators cannot reach it" do
      expect(owner_site.custom_field_groups).to include(mis_stamped)
    end
  end
end
