module SamsonPipelines
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, 'samson_pipelines/fields'

Samson::Hooks.callback :stage_permitted_params do
  { next_stage_ids: [] }
end

Samson::Hooks.callback :after_deploy do |deploy|
  begin
    return unless deploy.succeeded? || deploy.stage.next_stage_id.empty?

    log = ''
    Stage.find(deploy.stage.next_stage_ids).each do |next_stage|
      new_deploy = DeployService.new(deploy.user).deploy!(next_stage, deploy.commit)
      log += "Kicking off next stage: #{next_stage.name} - URL: #{new_deploy.url}\n"
    end
    deploy.job.reload.update_output!(deploy.job.output + "\n#{log}") if log.presence
  rescue => ex
    msg = "Failed to start the next deploy in the pipeline: #{ex.message}"
    Airbrake.notify(ex, parameters: { deploy: deploy })
    deploy.job.reload.update_output!(deploy.job.output + "\n#{msg}")
  end
end
