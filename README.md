# Morpheus

## Introduction

Morpheus is a service designed to ensure uninterrupted access to WordPress updates by mirroring the WordPress.org repository. If your WordPress site encounters difficulties connecting to WordPress.org for updates, Morpheus seamlessly steps in, providing identical updates from our mirrored server. It serves as a reliable backup solution for your WordPress update process. [Click here](https://github.com/blogvault/morpheus-plugin/releases/tag/Latest) to download the plugin

## Setup Instructions

1. Clone the repository:
   ```
   git clone https://github.com/blogvault/morpheus.git
   cd morpheus
   ```

2. Install dependencies:
   ```
   bundle install
   ```

3. Set up the configuration:
   - Copy `config/config.example.yml` to `config/config.yml`
   - Update the values in `config/config.yml` according to your environment

4. Set up Redis:
   - Ensure Redis is installed and running
   - Update the Redis configuration in `config/config.yml`

5. Start the Sinatra application:
   ```
   ruby app.rb
   ```

6. Start Sidekiq:
   ```
   bundle exec sidekiq -r ./job.rb
   ```

## Usage

To use Morpheus with your WordPress site:

1. Install the Morpheus plugin on your WordPress site [from here](https://github.com/blogvault/morpheus-plugin/releases/tag/Latest).
2. The plugin will connect to WordPress.org for updates by default.
3. If the connection to WordPress.org fails, the plugin will automatically switch to Morpheus.
4. Updates will be pulled from the Morpheus mirror server instead.

## Custom Plugin Support

Morpheus now supports custom plugins hosted on external platforms like GitHub. To add a custom plugin:

1. Edit `config/custom_plugins.yaml`
2. Add your custom plugin configuration. For example:

   ```yaml
   - slug: advanced-custom-fields
     system: github
     owner: AdvancedCustomFields
     repo: acf
     frequency: 60
   ```

   This configuration will fetch updates for the Advanced Custom Fields (ACF) plugin from its GitHub repository every 60 minutes.

   This feature was suggested by Imran Siddiq of [WebSquadron](https://www.youtube.com/watch?v=rtmQHIS2K-U)

## Current Limitations

- Morpheus currently only supports the core WordPress updates API and custom plugin updates from GitHub.
- At present, only English-language updates are supported.
- The focus is strictly on updates; installation of plugins and themes is not yet supported.

## Future Plans

- Support for updates in multiple languages.
- Expansion to handle plugin installations and theme updates.
- Full support for the entire WordPress API.

## License

Morpheus is released under the [MIT License](LICENSE).
