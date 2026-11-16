# frozen_string_literal: true

require 'selenium-webdriver'

# Chrome 157 gives an UnknownError ("Node with given id does not belong to the document") for a node of a
# page that a click replaced. That node is stale, but Capybara retries only a StaleElementReferenceError.
# This patch raises the error as a StaleElementReferenceError, so Capybara finds the node again.
module CamaSeleniumDetachedNode
  DETACHED_NODE = 'does not belong to the document'

  private

  def execute(*)
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.include?(DETACHED_NODE)

    raise Selenium::WebDriver::Error::StaleElementReferenceError, e.message
  end
end

Selenium::WebDriver::Remote::Bridge.prepend(CamaSeleniumDetachedNode)
