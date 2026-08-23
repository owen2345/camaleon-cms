# frozen_string_literal: true

# Guards the contract that both captcha entry points -- CamaleonCms::RuntimeCaptchaImageConcern
# (the controller stack serving GET /captcha) and CamaleonCms::CaptchaHelper (views and the
# runtime helper surface) -- resolve challenge/image generation to one shared implementation,
# so a captcha hardening fix cannot land in one and not the other. Before the extraction the
# two carried hand-synced copies, and the controller's ancestor order silently shadowed the
# helper's copy for GET /captcha.
# rubocop:disable RSpec/DescribeClass -- the subject is the contract across the shared module
# and two entry points, not any single one of them.
RSpec.describe 'captcha implementation parity' do
  concern = CamaleonCms::RuntimeCaptchaImageConcern
  helper = CamaleonCms::CaptchaHelper
  shared = CamaleonCms::CaptchaImageGeneration

  shared_public = %i[cama_captcha_build]
  shared_private = %i[cama_captcha_length resolve_captcha_file cama_rand_str]

  describe 'single definition site' do
    it 'defines no shared generation method directly on either entry point' do
      own = lambda do |mod|
        (mod.instance_methods(false) + mod.private_instance_methods(false)) & (shared_public + shared_private)
      end

      expect(own.call(concern)).to be_empty
      expect(own.call(helper)).to be_empty
    end

    (shared_public + shared_private).each do |name|
      it "resolves ##{name} to the shared module from both entry points" do
        expect(concern.instance_method(name).owner).to eq(shared)
        expect(helper.instance_method(name).owner).to eq(shared)
      end
    end

    it 'resolves the controller runtime (GET /captcha) to the shared implementation' do
      expect(CamaleonCms::CamaleonController.instance_method(:cama_captcha_build).owner).to eq(shared)
      expect(CamaleonCms::CamaleonController.instance_method(:cama_captcha_length).owner).to eq(shared)
    end

    it 'exposes one set of length-clamp constants through both entry points' do
      %i[CAPTCHA_MIN_LENGTH CAPTCHA_MAX_LENGTH CAPTCHA_DEFAULT_LENGTH].each do |const|
        expect(concern.const_get(const)).to eq(shared.const_get(const))
        expect(helper.const_get(const)).to eq(shared.const_get(const))
      end
    end
  end

  describe 'entry-point-specific code' do
    it 'keeps tag building, verification and the attack counters on the helper only' do
      helper_only = %i[cama_captcha_tag cama_captcha_verified? captcha_verify_if_under_attack
                       cama_captcha_under_attack? cama_captcha_increment_attack cama_captcha_reset_attack
                       cama_captcha_total_attacks cama_captcha_tags_if_under_attack]

      helper_only.each do |name|
        expect(helper.instance_method(name).owner).to eq(helper)
        expect(concern.instance_methods + concern.private_instance_methods).not_to include(name)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
