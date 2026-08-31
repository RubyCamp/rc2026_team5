class TutorialsController < ApplicationController
  def index
    @profiles = TutorialProfile.published

    if params[:category].present?
      @profiles = @profiles.select do |profile|
        profile.category == params[:category]
      end
    end

    if params[:q].present?
      @profiles = @profiles.select do |profile|
        profile.matches?(params[:q])
      end
    end

    @profiles = @profiles.sort_by(&:name)
  end

  def debug
    @profile = TutorialProfile.find(1)
  end

  def profiles
    @profile = TutorialProfile.find(params[:id])
  end
end
