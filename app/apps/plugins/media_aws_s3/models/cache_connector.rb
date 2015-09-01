class Plugins::MediaAwsS3::Models::CacheConnector < ElFinderS3::CacheConnector

  def initialize
    super(Rails.cache)
  end
end
