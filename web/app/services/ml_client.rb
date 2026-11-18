require "net/http"

class MlClient
  def initialize(base_url: ENV.fetch("ML_URL", "http://localhost:8000"), timeout: 3)
    @base = URI(base_url)
    @timeout = timeout
  end

  private

  def request(req)
    Net::HTTP.start(@base.host, @base.port, use_ssl: @base.scheme == "https", open_timeout: 1, read_timeout: @timeout) do |http|
      res = http.request(req)
      res.is_a?(Net::HTTPSuccess) ? JSON.parse(res.body) : nil
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, SystemCallError, SocketError, JSON::ParserError => e
    Rails.logger.warn("ml #{req.path}: #{e.class}")
    nil
  end

  def uri(path) = URI.join(@base.to_s, path)
end
