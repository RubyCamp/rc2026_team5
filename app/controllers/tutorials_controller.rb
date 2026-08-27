class TutorialsController < ApplicationController
  def index
    @profiles = TutorialProfile.all
  end

  def debug
    @profile = TutorialProfile.find(1)
  end
end
