class HomeController < ApplicationController
  def index
    @streams = Dir.glob(File.join(Rails.configuration.record_path, '*.png')).map {|path| File.basename(path, '.*')} 
  end

  def page
    @stream = params[:stream]
  end
end
