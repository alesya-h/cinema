require 'cinema/version'
require 'rest_client'
require 'launchy'
require 'tempfile'
require 'yify'
require 'yaml'
require 'pry'

module Cinema
  class << self
    APP_ID="69f18bbaff859f035d934888f846b7ae3653e223a2b0f15629bcc9b836d3996b"
    APP_SECRET="077edf5024fca4102295263e802631f52f8cebd404f612194279f059bc5d9b8d"

    def get_sorting_options(sample)
      sample.reduce([]) do |result, (k,v)|
        if v.is_a? Hash
          child_sorting_options = get_sorting_options(v).map do |name, accessor|
            ["#{k} #{name}", ->(x){ accessor.(x[k]) }]
          end
          result.concat child_sorting_options
        else
          result << [k.to_s, ->(x){ x[k] }]
        end
      end
    end

    def run_torrent(downloader, torrent)
      case downloader
      when 'peerflix'
        player = select("Select player", ["mplayer","vlc"])
        system downloader, torrent, "--#{player}"
      when 'qbittorrent'
        system "sh", "-c", "#{downloader} #{torrent} &"
      else
        system downloader, torrent
      end
    end

    def ask_and_play
      watchlist = get_watchlist
      sorting_options = get_sorting_options(watchlist.first)
      sort_getter = select("Order movie list by", sorting_options, &:first).last

      imdb_id = select("Select movie", watchlist.sort_by{|x| sort_getter.(x)}){ |x|
        "#{sort_getter.(x)}: #{x["movie"]["title"]}"
      }["movie"]["ids"]["imdb"]

      torrent = select("Select quality", torrents(imdb_id)){|x| x["quality"] }["url"]
      downloader = select("Select downloader", ["peerflix", "qbittorrent", "wget", "echo"])
      run_torrent(downloader, torrent)
    end

    def select(title, items, &title_proc)
      menu_items = items.each_with_index.map do |x,i|
        [i.to_s, (title_proc ? title_proc.(x) : x)]
      end
      index = capture_stderr do
        success = system 'dialog', '--title', title,
          '--menu', '', '0', '0', '0',
          *menu_items.flatten
        unless success
          exit 0
        end
      end
      items[index.to_i] if index
    end

    def get_watchlist
      with_unreliable_api do
        puts "Requesting watchlist..."
        trakt_request(:get, "sync/watchlist/movies")
      end
    end

    def torrents(imdb_id)
      with_unreliable_api do
        puts "Searching torrents..."
        response = RestClient.get("http://yts.ag/api/v2/list_movies.json?query_term=#{imdb_id}").body
        JSON.parse(response)["data"]["movies"].first["torrents"]
      end
    end

    def yify
      @yify ||= Yify::Client.new
    end

    def redirect_uri
      'urn:ietf:wg:oauth:2.0:oob'
    end

    def pin_to_token(pin)
      response =
        RestClient.post('https://trakt.tv/oauth/token', {
                          code: pin,
                          client_id: APP_ID,
                          client_secret: APP_SECRET,
                          redirect_uri: redirect_uri,
                          grant_type: 'authorization_code'
                        }).body
      JSON.parse(response).values_at('access_token', 'refresh_token')
    end

    def initial_authorize
      loop do
        capture_stderr do
          Launchy.open("https://trakt.tv/oauth/authorize?client_id=#{APP_ID}&redirect_uri=#{redirect_uri}&response_type=code")
        end
        print "Please authorize the app and enter PIN: "
        pin = gets.chomp
        if pin.size == 8
          return pin_to_token(pin)
        end
      end
    end

    def write_config(access_token, refresh_token)
      File.write config_file, {access_token: access_token, refresh_token: refresh_token}.to_yaml
    end

    def initial_authorize_and_save_config
      write_config(*initial_authorize)
    end

    def refresh_access_token
      response =
        RestClient.post('https://trakt.tv/oauth/token', {
                          refresh_token: config[:refresh_token],
                          client_id: APP_ID,
                          client_secret: APP_SECRET,
                          redirect_uri: redirect_uri,
                          grant_type: 'refresh_token'
                        }).body
      write_config *JSON.parse(response).values_at('access_token', 'refresh_token')
    end

    def trakt_request(method, path, payload=nil)
      params = {
        method: method,
        url: "https://api-v2launch.trakt.tv/#{path}",
        payload: payload,
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{config[:access_token]}",
          "trakt-api-version" => "2",
          "trakt-api-key" => APP_ID,
        }
      }
      JSON.parse RestClient::Request.execute(params).body
    rescue RestClient::Unauthorized
      puts 'Unauthorized. Trying to refresh token.'
      refresh_access_token
      retry
    end

    def config
      unless File.exist? config_file
        initial_authorize_and_save_config
      end
      YAML.load_file config_file
    end

    def config_file
      "#{ENV['HOME']}/.config/cinema.yml"
    end

    def with_unreliable_api(delay=3)
      begin
        yield
      rescue
        puts "Request failed. Retrying in #{delay} seconds..."
        sleep delay
        retry
      end
    end

    def capture_stderr
      backup_stderr = STDERR.dup
      begin
        Tempfile.open("captured_stderr") do |f|
          STDERR.reopen(f)
          yield
          f.rewind
          f.read
        end
      ensure
        STDERR.reopen backup_stderr
      end
    end
  end
end
