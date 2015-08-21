class WhateverController < APIController

  def upload
    # Do complicated super secret stuff

    render json: {success: true}
  end

  def index
    element = {}
    element['uno'] = 'uno'
    element['dos'] = 'dos'
    render json: element
  end

end
