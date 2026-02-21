class Admin::JobsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_job, only: %i[ show update ]

  def index
    @jobs = Job.includes(:quote_request, :user).recent_first
  end

  def show
  end

  def update
    if @job.update(job_params)
      redirect_to admin_job_path(@job), notice: "Job updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_job
    @job = Job.includes(:quote_request, :user).find(params[:id])
  end

  def job_params
    params.require(:job).permit(:status, :scheduled_on, :notes)
  end
end
