require 'yaml'
require 'yaml'

# Load configuration with aliases enabled
CONFIG = YAML.load_file(File.join(__dir__, '../../config/config.yml'), aliases: true)[ENV['RACK_ENV'] || 'development']

