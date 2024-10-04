# Morpheus

## Introduction

Morpheus is a service designed to ensure uninterrupted access to WordPress updates by mirroring the WordPress.org repository. If your WordPress site encounters difficulties connecting to WordPress.org for updates, Morpheus seamlessly steps in, providing identical updates from our mirrored server. It serves as a reliable backup solution for your WordPress update process.

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

1. Install the Morpheus plugin on your WordPress site.
2. The plugin will connect to WordPress.org for updates by default.
3. If the connection to WordPress.org fails, the plugin will automatically switch to Morpheus.
4. Updates will be pulled from the Morpheus mirror server instead.

For detailed usage instructions and API documentation, please refer to our [GitHub Wiki](https://github.com/your-repo/morpheus/wiki).

## Current Limitations

- Morpheus currently only supports the core WordPress updates API.
- At present, only English-language updates are supported.
- The focus is strictly on updates; installation of plugins and themes is not yet supported.

## Future Plans

- Support for updates in multiple languages.
- Expansion to handle plugin installations and theme updates.
- Full support for the entire WordPress API.

## Contributing

We welcome contributions to Morpheus! Please see our [Contributing Guidelines](CONTRIBUTING.md) for more information.

## License

Morpheus is released under the [MIT License](LICENSE).
