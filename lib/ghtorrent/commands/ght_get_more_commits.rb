require 'rubygems'
require 'time'

require 'ghtorrent/ghtorrent'
require 'ghtorrent/settings'
require 'ghtorrent/logging'
require 'ghtorrent/command'
require 'ghtorrent/retriever'

class GHTMoreCommitsRetriever < GHTorrent::Command

  include GHTorrent::Settings
  include GHTorrent::Retriever
  include GHTorrent::Persister

  def prepare_options(options)
    options.banner <<-BANNER
Retrieves more commits for the provided repository

#{command_name} [options] owner repo

#{command_name} options:
    BANNER

    options.opt :num, 'Number of commits to retrieve',
                :short => 'n', :default => -1, :type => :int
    options.opt :full, 'Retrieve all commits, filling in potential holes',
                :short => 'f', :default => -1, :type => :int
  end

  def validate
    super
    Trollop::die "Two arguments are required" unless args[0] && !args[0].empty?

    Trollop::die "-a and -n cannot be defined at the same time" \
      if not options[:all].nil? and not options[:foo].nil?
  end

  def logger
    @ght.logger
  end

  def persister
    @persister ||= connect(:mongo, settings)
    @persister
  end

  def ext_uniq
    @ext_uniq ||= config(:uniq_id)
    @ext_uniq
  end

  def go

    @ght ||= GHTorrent::Mirror.new(settings)
    user_entry = @ght.transaction{@ght.ensure_user(ARGV[0], false, false)}

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    user = user_entry[:login]

    repo_entry = @ght.transaction{@ght.ensure_repo(ARGV[0], ARGV[1], false, false, false)}

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    repo = repo_entry[:name]
    num_pages = if options[:num] == -1 then 1024 * 1024 else options[:n]/30 end
    num_pages = if options[:full] == -1 then num_pages else 1024 * 1024 end
    page = 0


    head = unless options[:full] == -1
             @ght.get_db.from(:commits).\
                      where(:commits__project_id => repo_entry[:id]).\
                      order(:created_at).\
                      first.\
                      select(:sha)
           else
             "master"
           end

    total_commits = 0
    while (page < num_pages)
      begin
        logger.debug("Retrieving more commits for #{user}/#{repo} from head: #{head}")

        commits = retrieve_commits(repo, head, user, 1)
        page += 1
        if commits.nil? or commits.empty? or commits.size == 1
          page = num_pages # To break the loop
          break
        end

        total_commits += commits.size
        head = commits.last['sha']

        commits.map do |c|
          @ght.transaction do
            @ght.ensure_commit(repo, c['sha'], user)
          end
        end
      rescue Exception => e
        logger.warn("Error processing: #{e}")
        logger.warn(e.backtrace.join("\n"))
      end
    end
    logger.debug("Processed #{total_commits} commits for #{user}/#{repo}")
  end
end


#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
