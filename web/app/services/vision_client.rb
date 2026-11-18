class VisionClient < MlClient
  def initialize(**) = super(timeout: 5, **)

  def classify(io, filename:, content_type:)
    req = Net::HTTP::Post.new(uri("/v1/vision"))
    req.set_form([ [ "image", io, { filename:, content_type: } ] ], "multipart/form-data")
    request(req)
  end
end
