# Stub assets:precompile / assets:clean for this API-only Rails app.
#
# Render's Ruby buildpack (and Heroku's) auto-runs these tasks after bundle
# install. Without an asset pipeline gem (sprockets-rails / propshaft) they
# don't exist and the build fails. These no-ops keep the post-build step
# happy without pulling in unused gems.

unless Rake::Task.task_defined?("assets:precompile")
  namespace :assets do
    task :precompile do
      puts "[assets:precompile] api-only — skipping"
    end

    task :clean do
      puts "[assets:clean] api-only — skipping"
    end
  end
end
