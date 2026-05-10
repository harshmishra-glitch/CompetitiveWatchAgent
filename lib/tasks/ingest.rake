namespace :ingest do
  desc "Ingest the universal restaurants.csv into the restaurants table. Usage: rake ingest:restaurants[path/to/restaurants.csv]"
  task :restaurants, [:path] => :environment do |_, args|
    path = args[:path].present? ? absolute_path(args[:path]) : Ingest::RestaurantsCsv::DEFAULT_PATH
    abort "file not found: #{path}" unless File.exist?(path)

    stats = Ingest::RestaurantsCsv.new(path: path).call
    puts "[#{File.basename(path)}] #{stats.inspect}"
  end

  desc "Ingest a single Data_<NMonth> folder. Usage: rake ingest:day[Data_6May]"
  task :day, [:folder] => :environment do |_, args|
    folder = args[:folder]
    abort "usage: rake ingest:day[Data_6May]" if folder.nil? || folder.empty?

    path = absolute_path(folder)
    abort "folder not found: #{path}" unless Dir.exist?(path)

    stats = Ingest::Day.new(folder: path).call
    puts "[#{File.basename(path)}] #{stats.inspect}"
  end

  desc "Ingest all Data_<NMonth> folders found in the project root"
  task all: :environment do
    folders = Dir.glob(Rails.root.join("Data_*")).select { |p| Dir.exist?(p) }.sort
    if folders.empty?
      puts "no Data_* folders found"
      next
    end

    folders.each do |path|
      next unless Dir.exist?(File.join(path, "googleReviews")) ||
                  Dir.exist?(File.join(path, "restaurantsAndMenus")) ||
                  Dir.exist?(File.join(path, "restaurantAndMenus")) ||
                  Dir.exist?(File.join(path, "instagramScrapes")) ||
                  Dir.exist?(File.join(path, "googleSerpScrapes"))
      stats = Ingest::Day.new(folder: path).call
      puts "[#{File.basename(path)}] #{stats.inspect}"
    rescue => e
      puts "[#{File.basename(path)}] ERROR: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  def absolute_path(folder)
    p = Pathname.new(folder)
    p.absolute? ? p.to_s : Rails.root.join(folder).to_s
  end
end
