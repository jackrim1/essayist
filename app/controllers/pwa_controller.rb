class PwaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: :service_worker

  def manifest
    render json: {
      name:             "Essayist",
      short_name:       "Essayist",
      description:      "Read and annotate essays",
      start_url:        "/",
      display:          "standalone",
      background_color: "#09090b",
      theme_color:      "#09090b",
      icons: [
        { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
        { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
      ],
    }
  end

  def service_worker
    render file: Rails.root.join("public/sw.js"), content_type: "application/javascript"
  end
end
