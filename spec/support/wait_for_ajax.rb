# spec/support/wait_for_ajax.rb
module WaitForAjax
  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end

  def wait_for_visible_modal(key = nil)
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until visible_modal?(key)
    end
  end

  def wait_for_hidden_modal(key = nil)
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until hidden_modal?(key)
    end
  end

  def hidden_modal?(key = nil)
    page.evaluate_script("jQuery('#{key || "#ow_inline_modal"}').is(':visible')") == false
  end

  def visible_modal?(key = nil)
    page.evaluate_script("jQuery('#{key || "#ow_inline_modal"}').is(':visible')") == true
  end
end

RSpec.configure do |config|
  config.include WaitForAjax, type: :feature
end