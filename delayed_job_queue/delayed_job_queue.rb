class DelayedJobQueue < Scout::Plugin  
  
  def build_report
    begin
      require "#{@options['path_to_app']}/config/environment"
    rescue
      error "Couldn't load rails environment at #{@options['path_to_app'].inspect}.", $!.message
    end

    report(:jobs_count => jobs_count)
    jobs_count_by_priority.each { |priority,count|
      # note: this only reports priorities of existing jobs
      report(:"jobs_with_priority_#{priority}_count" => count)
    }
    report(:jobs_with_errors_count => jobs_with_errors_count)

    # add age of oldest job
    # add alerts for jobs with errors
  end

  private

    # returns a hash where keys are priority and values are the counts.
    def jobs_count_by_priority
      results = Delayed::Job.all(:select => "priority, count(*) as count", :group => "priority")
      results.inject({}) { |memo, dj| memo[dj.priority] = dj.count; memo}
    end

    def jobs_count
      Delayed::Job.count
    end

    def jobs_with_errors_count
      Delayed::Job.count(:conditions => "last_error IS NOT NULL")
    end
end
