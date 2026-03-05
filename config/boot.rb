app_root = File.expand_path("..", __dir__)

if Gem.win_platform?
  normalize_windows_path = lambda do |path|
    expanded = File.expand_path(path).tr("\\", "/")
    drive, remainder = expanded.split(":/", 2)
    next expanded unless drive

    current = "#{drive.upcase}:/"

    remainder.to_s.split("/").reject(&:empty?).each do |segment|
      begin
        entries = Dir.children(current)
        match = entries.find { |entry| entry.casecmp(segment).zero? }
      rescue StandardError
        match = nil
      end

      current = File.join(current, match || segment)
    end

    current.tr("\\", "/")
  end

  app_root = normalize_windows_path.call(app_root)
  Dir.chdir(app_root) if Dir.exist?(app_root)
end

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("Gemfile", app_root)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
