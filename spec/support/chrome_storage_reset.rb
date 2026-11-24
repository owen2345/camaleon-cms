# frozen_string_literal: true

# After each example, Capybara clears the cookies and the local storage of the browser. For that, its
# Chrome driver sends the origin "*" to the DevTools command Storage.clearDataForOrigin. Chrome 158
# refuses that origin ("* is not a valid URL"), so each browser example failed after its body.
# When Chrome refuses the origin, this patch clears all the cookies. It also clears the local storage of
# each origin in the history of the first window, when Capybara clears the local storage. An origin that
# only a second window visited keeps its local storage. The specs use one origin, the Capybara server.
module CamaChromeStorageReset
  REFUSED_ORIGIN = '* is not a valid URL'

  def reset!
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError => e
    raise unless e.message.include?(REFUSED_ORIGIN)

    execute_cdp('Network.clearBrowserCookies')
    return unless clear_all_storage?

    visited_origins.each do |origin|
      execute_cdp('Storage.clearDataForOrigin', origin: origin, storageTypes: 'local_storage')
    end
  end

  private

  # Chrome accepts only an http or https origin, so a URL such as about:blank gives no origin.
  # The origin keeps the user and the password of a URL such as http://user:pass@host. Chrome 158
  # accepts that origin too, and clears the local storage of the host.
  def visited_origins
    entries = execute_cdp('Page.getNavigationHistory')['entries']
    entries.filter_map { |entry| entry['url'][%r{\Ahttps?://[^/?#]+}] }.uniq
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(CamaChromeStorageReset)
