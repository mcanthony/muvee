class TvShow < Video
  include HasMetadata

  belongs_to :series, counter_cache: true
  after_create :extract_metadata, unless: :reanalyzing_series
  after_create :associate_with_series, unless: :reanalyzing_series
  after_create :associate_with_genres

  validate :unique_episode_in_season, on: :create

  scope :latest, -> {order(season: :desc, episode: :desc)}
  scope :release_order, -> {order(season: :asc, episode: :asc)}

  attr_accessor :reanalyzing_series

  def unique_episode_in_season
    if series.present?
      self.errors.add(:unique_episode_in_season, 'Season&Episode must be unique within the context of a season') if series.tv_shows.find_by(season: season, episode: episode).present?
    end
  end

  def associate_with_series
    old_series = self.series.presence

    new_series = Series.find_or_create_by(title: title)
    self.series = new_series
    self.save

    Series.reset_counters(new_series.id, :tv_shows) if new_series.persisted?
    Series.reset_counters(old_series.id, :tv_shows) if old_series.present?
  end

  def season_episode
    self.class.format_season_and_episode(season, episode)
  end

  def self.format_season_and_episode(s, e)
    "S" + s.to_s.rjust(2, '0') + "E" + e.to_s.rjust(2, '0')
  end

  def associate_with_genres
    return if series_metadata[:Genre].blank?

    self.genres = []

    listed_genres = compute_genres(series_metadata[:Genre])
    listed_genres.each do |genre_name|
      self.genres << Genre.find_or_create_by(name: genre_name)
    end
    self.save if listed_genres.any?
  end

  def extract_metadata
    self.title = metadata[:SeriesName]
    self.overview = episode_specific_metadata[:Overview]
    self.episode_name = episode_specific_metadata[:EpisodeName]
    self.season = episode_specific_metadata[:SeasonNumber]
    self.episode = episode_specific_metadata[:EpisodeNumber]
  end

  def reanalyze
    super
    associate_with_series
    associate_with_genres
    extract_metadata
    self.save
  end

  def redownload; end
  def redownload_missing; end

end
