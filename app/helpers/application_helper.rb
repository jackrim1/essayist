module ApplicationHelper
  # Flash notice rendered as a dismissible toast at the bottom of the screen
  def flash_messages
    return unless flash.any?

    tags = flash.map do |type, message|
      color = type.to_s == "alert" ? "red" : "zinc"
      content_tag(:div,
        class: "fixed bottom-4 left-1/2 -translate-x-1/2 z-50 px-4 py-2.5 rounded-xl shadow-lg text-sm font-medium bg-#{color}-900 text-white",
        data:  { controller: "flash", action: "click->flash#dismiss" }) do
        message
      end
    end
    safe_join(tags)
  end
end
