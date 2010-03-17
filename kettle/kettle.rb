class Kettle < Scout::Plugin  
  
  # only report anything if this is the first time since a run (using memory)
  #
  # data points
  # - time_since_last_run
  # - iterate through jobs and report input and output numbers
  def build_report
    # try hard to remember this even if everything else goes wrong
    remember :last_log_date => memory(:last_log_date)

    load_rails_environment or return
    KettleJobMessage.last.logdate != memory(:last_log_date) or return

    # We should be here if its the first time scout has run since kettle
    report :time_since_last_run => (Time.now.utc - memory(:last_log_date)) if memory(:last_log_date)

    jobs = KettleJobMessage.all(:select => "distinct jobname").collect{|j| j.jobname}.sort

    jobs.each do |job|
      scope = KettleJobMessage.scoped :conditions => {:jobname => job}
      if memory(:last_log_date)
        scope = scope.scoped :conditions => ["logdate > ?", memory(:last_log_date)]
      end

      message = scope.first

      %w(lines_read lines_written lines_updated lines_input lines_output errors).each do |stat|
        report "#{job}_#{stat}" => message[stat]
      end
    end

    remember :last_log_date => KettleJobMessage.last.logdate
  end

  private

    # return true on success, false on error
    def load_rails_environment
      ENV['RAILS_ENV'] = @options['rails_env'] || 'production'
      require "#{@options['path_to_app']}/config/environment"
      true

    rescue Exception => e
      error \
        "Couldn't load rails environment at #{@options['path_to_app'].inspect}.", 
        "#{e.class.to_s}: #{e.message}"

      false
    end

end
