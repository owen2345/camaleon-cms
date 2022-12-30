/* eslint-env jquery */
(function($) {
  $.fn.extend({
    hoverZoom: function(settings) {
      const defaults = { overlay: true, overlayColor: '#2e9dbd', overlayOpacity: 0.9, zoom: 25, speed: 300 }

      const extendedSettings = $.extend(defaults, settings)

      return this.each(function() {
        const hz = $(this)
        const image = $('img', hz)

        image.load(function() {
          if (extendedSettings.overlay === true) {
            $(this).parent().append('<div class="zoomOverlay" />')
            $(this).parent().find('.zoomOverlay').css({
              opacity: 0,
              display: 'block',
              backgroundColor: extendedSettings.overlayColor
            })
          }

          const height = $(this).height()

          $(this).fadeIn(1000, function() {
            $(this).parent().css('background-image', 'none')
            hz.hover(function() {
              $('img', this).stop().animate({
                height: height + extendedSettings.zoom,
                marginLeft: -(extendedSettings.zoom),
                marginTop: -(extendedSettings.zoom)
              }, extendedSettings.speed)
              if (extendedSettings.overlay === true) {
                $(this).parent().find('.zoomOverlay').stop()
                  .animate({ opacity: extendedSettings.overlayOpacity }, extendedSettings.speed)
              }
            }, function() {
              $('img', this).stop().animate({ height, marginLeft: 0, marginTop: 0 }, extendedSettings.speed)
              if (extendedSettings.overlay === true)
                $(this).parent().find('.zoomOverlay').stop().animate({ opacity: 0 }, extendedSettings.speed)
            })
          })
        })
      })
    }
  })
})(jQuery)
