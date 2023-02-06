# Rake tasks for running unit tests with backend services running as docker containers

desc 'Run unit tests with docker based backend'
namespace :test do
  namespace :docker do
    task :up do
      system("docker compose up -d")
      system("docker compose ps")
    end
    task :down do
      system("docker compose --profile fs --profile ag stop")
      system("docker compose --profile fs --profile ag kill")
    end
    desc "run tests agains docker AG backend"
    task :ag do
      ENV["GOO_BACKEND_NAME"]="AG"
      ENV["GOO_PORT"]="10035"
      ENV["GOO_PATH_QUERY"]="/repositories/ontoportal_test"
      ENV["GOO_PATH_DATA"]="/repositories/ontoportal_test/statements"
      ENV["GOO_PATH_UPDATE"]="/repositories/ontoportal_test/statements"
      ENV["COMPOSE_PROFILES"]="ag"
      Rake::Task["test:docker:up"].invoke
      # AG takes some time to start and create databases/accounts
      printf("waiting for AG to come up")
      # TODO: replace system curl command with native ruby code
      until system("curl -sf http://127.0.0.1:10035/repositories/ontoportal_test/status | grep -iqE '(^running|^lingering)' || exit 1")
        sleep(1)
        printf(".")
      end
      puts
      system("docker compose ps") # TODO: remove after GH actions troubleshooting is complete
      Rake::Task["test"].invoke
      Rake::Task["test:docker:down"].invoke
    end

    desc "run tests agains docker 4store backend"
    task :fs do
      ENV["GOO_PORT"]="9000"
      ENV["COMPOSE_PROFILES"]='fs'
      Rake::Task["test:docker:up"].invoke
      Rake::Task["test"].invoke
      Rake::Task["test:docker:down"].invoke
    end
  end
end
