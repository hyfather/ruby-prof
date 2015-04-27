# encoding: utf-8

require 'uri'
require 'net/http'
require 'net/https'
require 'json'

module RubyProf
  # Generates flat[link:files/examples/flat_txt.html] profile reports as text.
  # To use the flat printer:
  #
  #   result = RubyProf.profile do
  #     [code to profile]
  #   end
  #
  #   printer = RubyProf::FlatPrinter.new(result)
  #   printer.print(STDOUT, {})
  #
  class SplunkVirtualPrinter < AbstractPrinter
    # Override for this printer to sort by self time by default
    def sort_method
      @options[:sort_method] || :self_time
    end

    private

    def print_header(thread)
      true
    end

    def print_methods(thread)
      total_time = thread.total_time
      methods = thread.methods.sort_by(&sort_method).reverse

      sum = 0
      json_events = []
      methods.each do |method|
        self_percent = (method.self_time / total_time) * 100
        next if self_percent < min_percent

        sum += method.self_time

        json_string = %Q(
        {
          "thread_id": "%d",
          "fiber_id": "%d",
          "thread_time": "%d",
          "percent_time": "%6.2f",
          "total_time": "%9.3f",
          "time": "%9.3f",
          "wait_time": "%9.3f",
          "children_time": "%9.3f",
          "called": "%8d",
          "recursive": "%s",
          "name": "%s"
        }) % [
              thread.id,
              thread.fiber_id,
              thread.total_time,
              method.self_time / total_time * 100, # %self
              method.total_time,                   # total
              method.self_time,                    # self
              method.wait_time,                    # wait
              method.children_time,                # children
              method.called,                       # calls
              method.recursive? ? "true" : "false",
              method_name(method)                  # name
             ]
        json_events << JSON.parse(json_string)
      end
      forward_to_splunk(json_events, @options)
    end

    def print_footer(thread)
      true
    end

    def forward_to_splunk(payload, params={})
      default_host = `hostname` rescue nil
      defaults = {
        :splunk_base_url => "https://localhost:8088",
        :splunk_endpoint => "/services/receivers/token/event",
        :splunk_auth => "Splunk DEADBEEF-CAFEBABE-CAFED00D",
        :host => default_host,
        :source => $0,
        :sourcetype => "apm_ruby"
      }
      options = defaults.merge params

      uri = URI.parse(options[:splunk_base_url] + options[:splunk_endpoint])
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.use_ssl = false
        request = Net::HTTP::POST.new uri
        request.initialize_http_header({
          'Authorization' => options[:splunk_auth]
        })

        [*payload].each do |j|
          data = {
            "event" => j,
            "host" => options[:host],
            "source" => options[:source],
            "sourcetype" => options[:sourcetype]
          }.to_json

          resp = http.request request
          if resp.code != "200"
            $stderr.puts("Failure when forwarding data to splunk.\
Response = #{resp.body}. Options used = #{options.to_s}.")
            return false # from forward_to_splunk
          end
        end # payload.each
      end # http
      return true
    end # forward_to_splunk
  end # class
end # module
