class DelayedJobQueue < Scout::Plugin  
  
  def build_report
    begin
      ENV['RAILS_ENV'] = @options['rails_env'] || 'production'
      require "#{@options['path_to_app']}/config/environment"
    rescue Exception => e
      error \
        "Couldn't load rails environment at #{@options['path_to_app'].inspect}.", 
        "#{e.class.to_s}: #{e.message}"
      return
    end

    report_jobs_count
    report_jobs_with_errors_count
    report_age_of_oldest_job
    report_jobs_count_by_priority if @options[:enable_jobs_by_priority]
    alert_jobs_with_errors if @options[:enable_alerts]
  end

  private

    def report_jobs_count
      report :jobs_count => Delayed::Job.count
    end
    
    def report_jobs_count_by_priority
      results = Delayed::Job.all \
        :select => "priority, count(*) as count", 
        :group => "priority"

      # note: this only reports priorities of existing jobs
      results.each { |j|
        report(:"jobs_with_priority_#{j.priority}_count" => j.count)
      }
    end

    def report_jobs_with_errors_count
      report(:jobs_with_errors_count => jobs_with_errors.length)
    end

    def jobs_with_errors
      Delayed::Job.all \
        :select => "id, last_error",
        :conditions => "last_error IS NOT NULL"
    end

    def report_age_of_oldest_job
      job = Delayed::Job.first \
        :select => "created_at", 
        :order => 'created_at ASC'
      age = job ? (Time.now - job.created_at) : 0
      report :age_of_oldest_job => age
    end

    def alert_jobs_with_errors
      previous_errors = memory(:known_errors) || {}
      known_errors = {}

      jobs_with_errors.each do |j|
        known_errors[j.id] = true
        unless previous_errors[j.id]
          alert "a job has encountered an error (id: #{j.id}).", j.last_error
        end
      end

      remember(:known_errors => known_errors)
    end
end
