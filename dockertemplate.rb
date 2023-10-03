run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "bootstrap", "~> 5.2"
    gem "devise"
    gem "autoprefixer-rails"
    gem "font-awesome-sass", "~> 6.1"
    gem "simple_form", github: "heartcombo/simple_form"

  RUBY
end

inject_into_file "Gemfile", after: 'gem "debug", platforms: %i[ mri mingw x64_mingw ]' do
  "\n  gem \"dotenv-rails\""
end

gsub_file("Gemfile", '# gem "sassc-rails"', 'gem "sassc-rails"')

# Assets
########################################
run "rm -rf app/assets/stylesheets"
run "rm -rf vendor"
run "curl -L https://github.com/lewagon/rails-stylesheets/archive/master.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm -f stylesheets.zip && rm -f app/assets/rails-stylesheets-master/README.md"
run "mv app/assets/rails-stylesheets-master app/assets/stylesheets"

# Layout
########################################

gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

# Flashes
########################################
file "app/views/shared/_flashes.html.erb", <<~HTML
  <% if notice %>
    <div class="alert alert-info alert-dismissible fade show m-1" role="alert">
      <%= notice %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
  <% if alert %>
    <div class="alert alert-warning alert-dismissible fade show m-1" role="alert">
      <%= alert %>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close">
      </button>
    </div>
  <% end %>
HTML

run "curl -L https://raw.githubusercontent.com/lewagon/awesome-navbars/master/templates/_navbar_wagon.html.erb > app/views/shared/_navbar.html.erb"

inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/navbar" %>
    <%= render "shared/flashes" %>
  HTML
end

# README
########################################
markdown_file_content = <<~MARKDOWN
  Rails app generated
MARKDOWN
file "README.md", markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

########################################
# After bundle
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  # rails_command "db:drop db:create db:migrate"
  generate("simple_form:install", "--bootstrap")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")

  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file ".gitignore", <<~TXT
    # Ignore .env file containing credentials.
    .env*

    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate("devise:install")
  generate("devise", "User")

  # Application controller
  ########################################
  run "rm app/controllers/application_controller.rb"
  file "app/controllers/application_controller.rb", <<~RUBY
    class ApplicationController < ActionController::Base
      before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  # rails_command "db:migrate"
  generate("devise:views")

  link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML
  button_to = <<~HTML
    <div class="d-flex align-items-center">
      <div>Unhappy?</div>
      <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete, class: "btn btn-link" %>
    </div>
  HTML
  gsub_file("app/views/devise/registrations/edit.html.erb", link_to, button_to)

  # Pages Controller
  ########################################
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: "development"
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: "production"

  # Bootstrap & Popper
  ########################################
  append_file "config/importmap.rb", <<~RUBY
    pin "bootstrap", to: "bootstrap.min.js", preload: true
    pin "@popperjs/core", to: "popper.js", preload: true
  RUBY

  append_file "config/initializers/assets.rb", <<~RUBY
    Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)
  RUBY

  append_file "app/javascript/application.js", <<~JS
    import "@popperjs/core"
    import "bootstrap"
  JS

  append_file "app/assets/config/manifest.js", <<~JS
    //= link popper.js
    //= link bootstrap.min.js
  JS

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Git initialize
  git :init
  git add: "."
  git commit: "-m 'Initialised the main app'"

  # Dotenv
  ########################################
  run "touch '.env'"
  append_file '.env', <<~TXT
    RAILS_ENV=production
    POSTGRES_HOST=db
    POSTGRES_DB=yourproject_production
    POSTGRES_USER=defaultuser
    POSTGRES_PASSWORD=password123
    RAILS_MASTER_KEY=your_rails_key
  TXT

  git add: "."
  git commit: "-m 'Updated env file'"

  # Database
  run "rm config/database.yml"
  run "touch 'config/database.yml'"

  append_file 'config/database.yml', <<~YML
    default: &default
      adapter: postgresql
      encoding: unicode
      pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      host: <%= ENV['POSTGRES_HOST'] %>
      port: 5432

    development:
      <<: *default
      database: docker_template_psql_development
      username: <%= ENV['POSTGRES_USER'] %>
      password: <%= ENV['POSTGRES_PASSWORD'] %>

    test:
      <<: *default
      database: docker_template_psql_test
      username: <%= ENV['POSTGRES_USER'] %>
      password: <%= ENV['POSTGRES_PASSWORD'] %>

    production:
      <<: *default
      database: <%= ENV['POSTGRES_DB'] %>
      username: <%= ENV['POSTGRES_USER'] %>
      password: <%= ENV['POSTGRES_PASSWORD'] %>
  YML

  git add: "."
  git commit: "-m 'Updated database'"

  # Rubocop
  ########################################
  run "touch '.rubocop.yml'"
  append_file '.rubocop.yml', <<~YML
    AllCops:
  NewCops: enable
  Exclude:
    - 'bin/**/*'
    - 'db/**/*'
    - 'config/**/*'
    - 'node_modules/**/*'
    - 'script/**/*'
    - 'support/**/*'
    - 'tmp/**/*'
    - 'test/**/*'
  Style/ConditionalAssignment:
    Enabled: false
  Style/StringLiterals:
    Enabled: false
  Style/RedundantReturn:
    Enabled: false
  Style/Documentation:
    Enabled: false
  Style/WordArray:
    Enabled: false
  Metrics/AbcSize:
    Enabled: false
  Style/MutableConstant:
    Enabled: false
  Style/SignalException:
    Enabled: false
  Metrics/CyclomaticComplexity:
    Enabled: false
  Style/MissingRespondToMissing:
    Enabled: false
  Lint/MissingSuper:
    Enabled: false
  Style/FrozenStringLiteralComment:
    Enabled: false
  Layout/LineLength:
    Max: 120
  Style/EmptyMethod:
    Enabled: false
  Bundler/OrderedGems:
    Enabled: false
  YML

  git add: "."
  git commit: "-m 'Updated rubocop'"

  # Docker
  run "bundle add dockerfile-rails --optimistic --group development"
  run "./bin/rails generate dockerfile"

  gsub_file(
    "Dockerfile",
    'apt-get install --no-install-recommends -y build-essential libpq-dev',
    'apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config bash bash-completion libffi-dev tzdata postgresql nodejs npm yarn'
  )



  run "touch '.docker-compose.yml'"
  append_file '.docker-compose.yml', <<~YML
    version: '3'
    services:
      db:
        image: postgres:14.2-alpine
        container_name: project-postgres-14.2
        volumes:
          - postgres_data:/var/lib/postgresql/data
        command:
          "postgres -c 'max_connections=500'"
        environment:
          - POSTGRES_DB=${POSTGRES_DB}
          - POSTGRES_USER=${POSTGRES_USER}
          - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
        ports:
          - "5432:5432"
      web:
        build: .
        command: "./bin/rails server"
        environment:
          - RAILS_ENV=${RAILS_ENV}
          - POSTGRES_HOST=${POSTGRES_HOST}
          - POSTGRES_DB=${POSTGRES_DB}
          - POSTGRES_USER=${POSTGRES_USER}
          - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
          - RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
        volumes:
          - app-storage:/rails/storage
        depends_on:
          - db
        ports:
          - "3000:3000"

    volumes:
      postgres_data: {}
      app-storage: {}
  YML

  inject_into_file "bin/docker-entrypoint", after: 'if [ "${*}" == "./bin/rails server" ]; then' do
    <<~TEXT
      ./bin/rails db:create
    TEXT
  end



  # Git
  ########################################
  git add: "."
  git commit: "-m 'Updated the docker components'"
end
