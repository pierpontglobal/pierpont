module ApplicationHelper
  def usd(amount) = amount ? number_to_currency(amount, precision: 0) : "—"
  def miles(n) = "#{number_with_delimiter(n)} mi"

  def countdown_tag(auction, **opts)
    urgent = auction.live? && auction.ends_at - Time.current < 10.minutes
    tag.span(auction.live? ? distance_of_time_in_words_to_now(auction.ends_at) : "Ended",
             class: [ "countdown", opts[:class], ("urgent" if urgent) ].compact.join(" "),
             data: { controller: "countdown", countdown_ends_at_value: auction.ends_at.iso8601 })
  end

  def vehicle_image(vehicle, variant, **opts)
    if vehicle.photo.attached?
      image_tag(vehicle.photo.variant(variant), alt: vehicle.title, loading: opts.fetch(:loading, "lazy"), decoding: "async")
    else
      tag.div(class: "placeholder")
    end
  end
end
