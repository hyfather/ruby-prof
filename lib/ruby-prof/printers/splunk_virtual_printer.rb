# encoding: utf-8

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
              thread.fiber_id unless thread.id == thread.fiber_id,
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
        json_event = JSON.parse(json_string)
        @output << json_event.to_hash.to_s
      end
    end

    def print_footer(thread)
      true
    end
  end
end
