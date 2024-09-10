require 'sinatra'
require 'sass-embedded'
require 'fileutils'
require 'bootstrap'

set :bind, '0.0.0.0'

# Define the SCSS content, you can use the Bootstrap gem's path to reference its files
BOOTSTRAP_SCSS_PATH = File.join(Gem.loaded_specs['bootstrap'].full_gem_path, 'assets/stylesheets')
VARIABLES_SCSS_PATH = File.join(BOOTSTRAP_SCSS_PATH, 'bootstrap/_variables.scss')
CACHE_DIR = 'cache'

# Load valid Bootstrap variable names from the _variables.scss file
def load_bootstrap_variables
  variables = []

  # Open and read the variables.scss file line by line
  File.foreach(VARIABLES_SCSS_PATH) do |line|
    # Match simple variables (e.g., $primary: #fff !default;)
    if match = line.match(/^\$(\w[\w-]*):/)
      variables << match[1]
    end

    # Match maps (e.g., $grays: ( ... ) !default;)
    if match = line.match(/^\$(\w[\w-]*): \(/)
      variables << match[1]
    end
  end

  variables
end


# Cache valid Bootstrap variable names
VALID_BOOTSTRAP_VARIABLES = load_bootstrap_variables

def cache_file_name(full_path, params)
  param_string = params.sort.to_h.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')
  digest = Digest::MD5.hexdigest(param_string)
  dirname = File.dirname(full_path)
  basename = File.basename(full_path)
  "#{CACHE_DIR}#{dirname}/#{digest}/#{basename}"
end

# Helper method to compile Bootstrap SCSS to CSS using sass-embedded
def compile_bootstrap_scss(overrides, minify: true)
  scss_content = overrides.map { |var, value| "$#{var}: #{value};" }.join("\n")
  scss_content += "\n@import 'bootstrap';"

  options = {
    load_paths: [BOOTSTRAP_SCSS_PATH],
    syntax: :scss,
    style: minify ? :compressed : :expanded
  }

  result = Sass.compile_string(scss_content, **options)
  [scss_content, result.css]
end

# Extract the query parameters that match Bootstrap SCSS variables
def overrides
  @overrides ||= params.select { |key, value| VALID_BOOTSTRAP_VARIABLES.include?(key) }
end

# Return an error if there are invalid variables
def validate_params!
  invalid_variables = params.keys - overrides.keys

  unless invalid_variables.empty?
    suggestions = invalid_variables.map do |var|
      spell_checker = DidYouMean::SpellChecker.new(dictionary: VALID_BOOTSTRAP_VARIABLES)
      [var, spell_checker.correct(var)]
    end
    body = "Invalid variables:"
    suggestions.each do |var, suggestion|
      body += "\n#{var}: did you mean '#{suggestion.first}'?"
    end
    halt 400, body
  end
end

def serve_cached(minify: true)
  cache_file_path = cache_file_name(request.path_info, overrides)

  # Check if the cache exists and is up-to-date
  if File.exist?(cache_file_path)
    File.read(cache_file_path) # Serve the cached file
  else
    # Compile and cache the CSS with the overrides
    scss_content, css_content = compile_bootstrap_scss(overrides, minify: minify)

    dirname = File.dirname(cache_file_path)
    FileUtils.mkdir_p(dirname)
    File.write("#{dirname}/instructions.scss", scss_content)
    File.write(cache_file_path, css_content)
    css_content
  end
end

# Route to serve the compiled Bootstrap CSS
get '/bootstrap@5.3.3/dist/css/bootstrap.min.css' do
  content_type 'text/css'
  validate_params!
  serve_cached
end

get '/bootstrap@5.3.3/dist/css/bootstrap.css' do
  content_type 'text/css'
  validate_params!
  serve_cached(minify: false)
end

get '/bootstrap@5.3.3/dist/js/bootstrap.min.js' do
  content_type 'application/javascript'
  File.read(File.join(Gem.loaded_specs['bootstrap'].full_gem_path, 'assets/javascripts/bootstrap.min.js'))
end

get '/up' do
  "<body style='background-color:green'>Hello, world!</body>"
end

get '/' do
  erb :home
end
