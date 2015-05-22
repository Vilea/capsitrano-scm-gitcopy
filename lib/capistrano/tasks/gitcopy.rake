namespace :gitcopy do

  archive_name =  "archive.#{ DateTime.now.strftime('%Y%m%d%m%s') }.tar.gz" 
  temp_clone = "clone"

  desc "Archive files to #{archive_name}"
  file archive_name do |file| 
    system "git ls-remote #{fetch(:repo_url)} | grep #{fetch(:branch)}"
    if $?.exitstatus == 0
      #system "git archive --remote #{fetch(:repo_url)} --format=tar #{fetch(:branch)}:#{fetch(:sub_directory)} | gzip > #{ archive_name }"
      # git archive --remote is only supported via git protocol :(
      system "git clone #{fetch(:repo_url)} #{ temp_clone }"
      system "cd #{ temp_clone } && git checkout #{fetch(:branch)} && git archive --format=tar #{fetch(:branch)}:#{fetch(:sub_directory)} | gzip > #{ File.join('..', archive_name) }"
      system "cd .. && rm -rf #{ temp_clone }"
    else
      puts "Can't find commit for: #{fetch(:branch)}"
    end
  end

  desc "Deploy #{archive_name} to release_path"
  task :deploy => archive_name do |file|
    tarball = file.prerequisites.first
    on roles :all do
      # Make sure the release directory exists
      execute :mkdir, "-p", release_path

      # Create a temporary file on the server
      tmp_file = capture("mktemp")

      # Upload the archive, extract it and finally remove the tmp_file
      upload!(tarball, tmp_file)
      execute :tar, "-xzf", tmp_file, "-C", release_path
      execute :rm, tmp_file
    end
  end


  task :clean do |t|
    # Delete the local archive
    File.delete archive_name if File.exists? archive_name
    FileUtils.rm_r temp_clone if File.exists? temp_clone
  end
  after 'deploy:finished', 'gitcopy:clean'


  task :create_release => :deploy

  task :check

  task :set_current_revision

end
