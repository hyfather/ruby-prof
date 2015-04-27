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

    #def print_threads
    #  @result.threads.each do |thread|
    #    print_thread(thread)
    #    @output << "\n" * 2
    #  end
    #end

    def print_header(thread)
      @output << "Measure Mode: %s\n" % RubyProf.measure_mode_string
      @output << "Thread ID: %d\n" % thread.id
      @output << "Fiber ID: %d\n" % thread.fiber_id unless thread.id == thread.fiber_id
      @output << "Total: %0.6f\n" % thread.total_time
      @output << "Sort by: #{sort_method}\n"
      @output << "\n"
      @output << " %self      total      self      wait     child     calls  name\n"
    end

    def print_methods(thread)
      total_time = thread.total_time
      methods = thread.methods.sort_by(&sort_method).reverse

      sum = 0
      methods.each do |method|
        self_percent = (method.self_time / total_time) * 100
        next if self_percent < min_percent

        sum += method.self_time
        #self_time_called = method.called > 0 ? method.self_time/method.called : 0
        #total_time_called = method.called > 0? method.total_time/method.called : 0

        json_string = %Q(
        {
          "percent_time": "%6.2f",
          "total_time": "%9.3f",
          "time": "%9.3f",
          "wait_time": "%9.3f",
          "children_time": "%9.3f",
          "called": "%8d",
          "recursive": "%s",
          "name": "%s"
        }) % [
              method.self_time / total_time * 100, # %self
              method.total_time,                   # total
              method.self_time,                    # self
              method.wait_time,                    # wait
              method.children_time,                # children
              method.called,                       # calls
              method.recursive? ? "*" : " ",       # cycle
              method_name(method)                  # name
             ]
        json_event = JSON.parse(json_string)
        @output << json_event.to_hash.to_s
      end
    end

    def print_footer(thread)
      @output << "\n"
      @output << "* indicates recursively called methods\n"
    end
  end
end
