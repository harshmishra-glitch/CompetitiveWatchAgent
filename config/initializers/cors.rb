# Be sure to restart your server when you modify this file.
#
# Cross-Origin Resource Sharing — allow the frontend (local + Vercel) to hit
# this API. Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(
      "http://localhost:3000",
      "http://localhost:3001",
      "https://competitor-watch-ten.vercel.app"
    )

    resource "*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose:  %w[X-Pilot-Restaurant-Id],
             max_age: 600
  end
end
